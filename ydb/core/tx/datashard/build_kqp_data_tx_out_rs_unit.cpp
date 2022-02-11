#include "datashard_impl.h"
#include "datashard_kqp.h"
#include "datashard_pipeline.h"
#include "execution_unit_ctors.h"
#include "setup_sys_locks.h"

#include <ydb/core/kqp/rm/kqp_rm.h>

namespace NKikimr {
namespace NDataShard {

using namespace NMiniKQL;

#define LOG_T(stream) LOG_TRACE_S(ctx, NKikimrServices::TX_DATASHARD, stream)
#define LOG_D(stream) LOG_DEBUG_S(ctx, NKikimrServices::TX_DATASHARD, stream)
#define LOG_E(stream) LOG_ERROR_S(ctx, NKikimrServices::TX_DATASHARD, stream)
#define LOG_C(stream) LOG_CRIT_S(ctx, NKikimrServices::TX_DATASHARD, stream)
#define LOG_W(stream) LOG_WARN_S(ctx, NKikimrServices::TX_DATASHARD, stream)

class TBuildKqpDataTxOutRSUnit : public TExecutionUnit {
public:
    TBuildKqpDataTxOutRSUnit(TDataShard& dataShard, TPipeline& pipeline);
    ~TBuildKqpDataTxOutRSUnit() override;

    bool IsReadyToExecute(TOperation::TPtr op) const override;
    EExecutionStatus Execute(TOperation::TPtr op, TTransactionContext& txc, const TActorContext& ctx) override;
    void Complete(TOperation::TPtr op, const TActorContext& ctx) override;

private:
    EExecutionStatus OnTabletNotReady(TActiveTransaction& tx, TValidatedDataTx& dataTx, TTransactionContext& txc,
                                      const TActorContext& ctx);
};

TBuildKqpDataTxOutRSUnit::TBuildKqpDataTxOutRSUnit(TDataShard& dataShard, TPipeline& pipeline)
    : TExecutionUnit(EExecutionUnitKind::BuildKqpDataTxOutRS, true, dataShard, pipeline) {}

TBuildKqpDataTxOutRSUnit::~TBuildKqpDataTxOutRSUnit() {}

bool TBuildKqpDataTxOutRSUnit::IsReadyToExecute(TOperation::TPtr) const {
    return true;
}

EExecutionStatus TBuildKqpDataTxOutRSUnit::Execute(TOperation::TPtr op, TTransactionContext& txc,
    const TActorContext& ctx)
{
    TSetupSysLocks guardLocks(op, DataShard);
    TActiveTransaction* tx = dynamic_cast<TActiveTransaction*>(op.Get());
    Y_VERIFY_S(tx, "cannot cast operation of kind " << op->GetKind());

    DataShard.ReleaseCache(*tx);

    if (tx->IsTxDataReleased()) {
        switch (Pipeline.RestoreDataTx(tx, txc, ctx)) {
            case ERestoreDataStatus::Ok:
                break;
            case ERestoreDataStatus::Restart:
                return EExecutionStatus::Restart;
            case ERestoreDataStatus::Error:
                Y_FAIL("Failed to restore tx data: %s", tx->GetDataTx()->GetErrors().c_str());
        }
    }

    const auto& dataTx = tx->GetDataTx();
    ui64 tabletId = DataShard.TabletID();

    if (tx->GetDataTx()->CheckCancelled()) {
        tx->ReleaseTxData(txc, ctx);
        BuildResult(op, NKikimrTxDataShard::TEvProposeTransactionResult::CANCELLED)
            ->AddError(NKikimrTxDataShard::TError::EXECUTION_CANCELLED, "Tx was cancelled");

        DataShard.IncCounter(op->IsImmediate() ? COUNTER_IMMEDIATE_TX_CANCELLED : COUNTER_PLANNED_TX_CANCELLED);

        return EExecutionStatus::Executed;
    }

    try {
        const auto& kqpTx = dataTx->GetKqpTransaction();
        auto& tasksRunner = dataTx->GetKqpTasksRunner();

        auto allocGuard = tasksRunner.BindAllocator(txc.GetMemoryLimit() - dataTx->GetTxSize());

        NKqp::NRm::TKqpResourcesRequest req;
        req.MemoryPool = NKqp::NRm::EKqpMemoryPool::DataQuery;
        req.Memory = txc.GetMemoryLimit();
        ui64 taskId = kqpTx.GetTasks().empty() ? std::numeric_limits<ui64>::max() : kqpTx.GetTasks()[0].GetId();
        NKqp::GetKqpResourceManager()->NotifyExternalResourcesAllocated(tx->GetTxId(), taskId, req);

        Y_DEFER {
            NKqp::GetKqpResourceManager()->NotifyExternalResourcesFreed(tx->GetTxId(), taskId);
        };

        LOG_T("Operation " << *op << " (build_kqp_data_tx_out_rs) at " << tabletId
            << " set memory limit " << (txc.GetMemoryLimit() - dataTx->GetTxSize()));

        dataTx->SetReadVersion(DataShard.GetReadWriteVersions(tx).ReadVersion);

        if (dataTx->GetKqpComputeCtx().HasPersistentChannels()) {
            auto result = KqpRunTransaction(ctx, op->GetTxId(), dataTx->GetKqpTasks(), tasksRunner);

            if (result == NYql::NDq::ERunStatus::PendingInput && dataTx->GetKqpComputeCtx().IsTabletNotReady()) {
                allocGuard.Release();
                return OnTabletNotReady(*tx, *dataTx, txc, ctx);
            }
        }

        KqpFillOutReadSets(op->OutReadSets(), kqpTx, tasksRunner, DataShard.SysLocksTable(), tabletId);
    } catch (const TMemoryLimitExceededException&) {
        LOG_T("Operation " << *op << " at " << tabletId
            << " exceeded memory limit " << txc.GetMemoryLimit()
            << " and requests " << txc.GetMemoryLimit() * MEMORY_REQUEST_FACTOR
            << " more for the next try");

        txc.NotEnoughMemory();
        DataShard.IncCounter(DataShard.NotEnoughMemoryCounter(txc.GetNotEnoughMemoryCount()));

        txc.RequestMemory(txc.GetMemoryLimit() * MEMORY_REQUEST_FACTOR);
        tx->ReleaseTxData(txc, ctx);

        return EExecutionStatus::Restart;
    } catch (const TNotReadyTabletException&) {
        LOG_C("Unexpected TNotReadyTabletException exception at build out rs");
        return OnTabletNotReady(*tx, *dataTx, txc, ctx);
    } catch (const yexception& e) {
        LOG_C("Exception while preparing out-readsets for KQP transaction " << *op << " at " << DataShard.TabletID()
            << ": " << e.what());
        if (op->IsReadOnly() || op->IsImmediate()) {
            tx->ReleaseTxData(txc, ctx);
            BuildResult(op, NKikimrTxDataShard::TEvProposeTransactionResult::EXEC_ERROR)
                ->AddError(NKikimrTxDataShard::TError::PROGRAM_ERROR, TStringBuilder() << "Tx was terminated: " << e.what());
            return EExecutionStatus::Executed;
        } else {
            Y_FAIL_S("Unexpected exception in KQP out-readsets prepare: " << e.what());
        }
    }

    return EExecutionStatus::Executed;
}

void TBuildKqpDataTxOutRSUnit::Complete(TOperation::TPtr, const TActorContext&) {}

EExecutionStatus TBuildKqpDataTxOutRSUnit::OnTabletNotReady(TActiveTransaction& tx, TValidatedDataTx& dataTx,
    TTransactionContext& txc, const TActorContext& ctx)
{
    LOG_T("Tablet " << DataShard.TabletID() << " is not ready for " << tx << " execution");

    DataShard.IncCounter(COUNTER_TX_TABLET_NOT_READY);

    ui64 pageFaultCount = tx.IncrementPageFaultCount();
    dataTx.GetKqpComputeCtx().PinPages(dataTx.TxInfo().Keys, pageFaultCount);

    tx.ReleaseTxData(txc, ctx);
    return EExecutionStatus::Restart;
}

THolder<TExecutionUnit> CreateBuildKqpDataTxOutRSUnit(TDataShard& dataShard, TPipeline& pipeline) {
    return THolder(new TBuildKqpDataTxOutRSUnit(dataShard, pipeline));
}

} // namespace NDataShard
} // namespace NKikimr
