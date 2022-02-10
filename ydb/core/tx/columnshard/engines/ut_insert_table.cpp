#include <library/cpp/testing/unittest/registar.h>
#include <util/string/printf.h>
#include "db_wrapper.h"
#include "insert_table.h"

namespace NKikimr {

using namespace NOlap;

namespace {

class TTestInsertTableDB : public IDbWrapper {
public:
    void Insert(const TInsertedData&) override {}
    void Commit(const TInsertedData&) override {}
    void Abort(const TInsertedData&) override {}
    void EraseInserted(const TInsertedData&) override {}
    void EraseCommitted(const TInsertedData&) override {}
    void EraseAborted(const TInsertedData&) override {}

    bool Load(THashMap<TWriteId, TInsertedData>&,
              THashMap<ui64, TSet<TInsertedData>>&,
              THashMap<TWriteId, TInsertedData>&,
              const TInstant&) override
    {
        return true;
    }

    void WriteGranule(ui32, const TGranuleRecord&) override {}
    void EraseGranule(ui32, const TGranuleRecord&) override {}
    bool LoadGranules(ui32, std::function<void(TGranuleRecord&&)>) override { return true; }

    void WriteColumn(ui32, const TColumnRecord&) override {}
    void EraseColumn(ui32, const TColumnRecord&) override {}
    bool LoadColumns(ui32, std::function<void(TColumnRecord&&)>) override { return true; }

    void WriteCounter(ui32, ui32, ui64) override {}
    bool LoadCounters(ui32, std::function<void(ui32 id, ui64 value)>) override { return true; }
};

}


Y_UNIT_TEST_SUITE(TColumnEngineTestInsertTable) {
    Y_UNIT_TEST(TestInsertCommit) {
        ui64 metaShard = 100500;
        ui64 writeId = 0;
        ui64 tableId = 0;
        TString dedupId = "0";
        TUnifiedBlobId blobId1(2222, 1, 1, 100, 1);

        TTestInsertTableDB dbTable;
        TInsertTable insertTable;

        // insert, not commited
        TInstant time = TInstant::Now();
        bool ok = insertTable.Insert(dbTable, TInsertedData(metaShard, writeId, tableId, dedupId, blobId1, {}, time));
        UNIT_ASSERT(ok);

        // insert the same blobId1 again
        ok = insertTable.Insert(dbTable, TInsertedData(metaShard, writeId, tableId, dedupId, blobId1, {}, time));
        UNIT_ASSERT(!ok);

        // insert different blodId with the same writeId and dedupId
        TUnifiedBlobId blobId2(2222, 1, 2, 100, 1);
        ok = insertTable.Insert(dbTable, TInsertedData(metaShard, writeId, tableId, dedupId, blobId2, {}, time));
        UNIT_ASSERT(!ok);

        // read nothing
        auto blobs = insertTable.Read(tableId, 0, 0);
        UNIT_ASSERT_EQUAL(blobs.size(), 0);
        blobs = insertTable.Read(tableId+1, 0, 0);
        UNIT_ASSERT_EQUAL(blobs.size(), 0);

        // commit
        ui64 planStep = 100;
        ui64 txId = 42;
        insertTable.Commit(dbTable, planStep, txId, metaShard, {TWriteId{writeId}});

        auto committed = insertTable.GetCommitted();
        UNIT_ASSERT_EQUAL(committed.size(), 1);
        UNIT_ASSERT_EQUAL(committed.begin()->second.size(), 1);

        // read old snapshot
        blobs = insertTable.Read(tableId, 0, 0);
        UNIT_ASSERT_EQUAL(blobs.size(), 0);
        blobs = insertTable.Read(tableId+1, 0, 0);
        UNIT_ASSERT_EQUAL(blobs.size(), 0);

        // read new snapshot
        blobs = insertTable.Read(tableId, planStep, txId);
        UNIT_ASSERT_EQUAL(blobs.size(), 1);
        blobs = insertTable.Read(tableId+1, 0, 0);
        UNIT_ASSERT_EQUAL(blobs.size(), 0);
    }
}

}
