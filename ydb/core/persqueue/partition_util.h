#pragma once

#include "partition.h"

namespace NKikimr::NPQ {

class TKeyLevel {
public:
    friend IOutputStream& operator <<(IOutputStream& out, const TKeyLevel& value);

    TKeyLevel(ui32 border)
    : Border_(border)
    , Sum_(0)
    , RecsCount_(0)
    , InternalPartsCount_(0) {}

    void Clear() {
        Keys_.clear();
        Sum_ = 0;
        RecsCount_ = 0;
        InternalPartsCount_ = 0;
    }

    ui32 KeysCount() const {
        return Keys_.size();
    }

    ui32 RecsCount() const {
        return RecsCount_;
    }

    ui16 InternalPartsCount() const {
        return InternalPartsCount_;
    }

    bool NeedCompaction() const {
        return Sum_ >= Border_;
    }

    std::pair<TKey, ui32> Compact() {
        Y_VERIFY(!Keys_.empty());
        TKey tmp(Keys_.front().first);
        tmp.SetCount(RecsCount_);
        tmp.SetInternalPartsCount(InternalPartsCount_);
        std::pair<TKey, ui32> res(tmp, Sum_);
        Clear();
        return res;
    }

    std::pair<TKey, ui32> PopFront() {
        Y_VERIFY(!Keys_.empty());
        Sum_ -= Keys_.front().second;
        RecsCount_ -= Keys_.front().first.GetCount();
        InternalPartsCount_ -= Keys_.front().first.GetInternalPartsCount();
        auto res = Keys_.front();
        Keys_.pop_front();
        return res;
    }

    std::pair<TKey, ui32> PopBack() {
        Y_VERIFY(!Keys_.empty());
        Sum_ -= Keys_.back().second;
        RecsCount_ -= Keys_.back().first.GetCount();
        InternalPartsCount_ -= Keys_.back().first.GetInternalPartsCount();
        auto res = Keys_.back();
        Keys_.pop_back();
        return res;
    }

    ui32 Sum() const {
        return Sum_;
    }

    const TKey& GetKey(const ui32 pos) const {
        Y_VERIFY(pos < Keys_.size());
        return Keys_[pos].first;
    }

    const ui32& GetSize(const ui32 pos) const {
        Y_VERIFY(pos < Keys_.size());
        return Keys_[pos].second;
    }

    void PushKeyToFront(const TKey& key, ui32 size) {
        Sum_ += size;
        RecsCount_ += key.GetCount();
        InternalPartsCount_ += key.GetInternalPartsCount();
        Keys_.push_front(std::make_pair(key, size));
    }

    void AddKey(const TKey& key, ui32 size) {
        Sum_ += size;
        RecsCount_ += key.GetCount();
        InternalPartsCount_ += key.GetInternalPartsCount();
        Keys_.push_back(std::make_pair(key, size));
    }

    ui32 Border() const {
        return Border_;
    }

private:
    const ui32 Border_;
    std::deque<std::pair<TKey, ui32>> Keys_;
    ui32 Sum_;
    ui32 RecsCount_;
    ui16 InternalPartsCount_;
};

void AddCheckDiskRequest(TEvKeyValue::TEvRequest *request, ui32 numChannels);
void RequestInfoRange(const TActorContext& ctx, const TActorId& dst, ui32 partition, const TString& key);
void RequestDataRange(const TActorContext& ctx, const TActorId& dst, ui32 partition, const TString& key);

} // namespace NKikimr::NPQ
