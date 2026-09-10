package com.luckysign.repository;

import com.luckysign.entity.CheckinRecord;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface CheckinRecordRepository extends JpaRepository<CheckinRecord, Long> {
    List<CheckinRecord> findByUserIdOrderByCheckinDateDesc(Long userId);

    java.util.Optional<CheckinRecord> findByUserIdAndCheckinDate(Long userId, java.time.LocalDate checkinDate);
}
