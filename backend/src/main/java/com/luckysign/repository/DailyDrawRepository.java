package com.luckysign.repository;

import com.luckysign.entity.DailyDraw;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface DailyDrawRepository extends JpaRepository<DailyDraw, Long> {
    Optional<DailyDraw> findByUserIdAndDrawDate(Long userId, LocalDate drawDate);
    List<DailyDraw> findByDrawDate(LocalDate drawDate);
    List<DailyDraw> findByUserIdAndDrawDateGreaterThanEqualOrderByDrawDateDesc(Long userId, LocalDate from);
}
