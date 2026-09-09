package com.luckysign.repository;

import com.luckysign.entity.CircleDailyStar;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.Optional;

public interface CircleDailyStarRepository extends JpaRepository<CircleDailyStar, Long> {
    Optional<CircleDailyStar> findByCircleIdAndStarDate(Long circleId, LocalDate starDate);
}
