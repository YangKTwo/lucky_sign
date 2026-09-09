package com.luckysign.repository;

import com.luckysign.entity.Circle;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface CircleRepository extends JpaRepository<Circle, Long> {
    Optional<Circle> findFirstByOrderByIdAsc();
}
