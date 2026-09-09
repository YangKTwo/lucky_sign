package com.luckysign.repository;

import com.luckysign.entity.CircleMember;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface CircleMemberRepository extends JpaRepository<CircleMember, Long> {
    List<CircleMember> findByCircleId(Long circleId);
    Optional<CircleMember> findByCircleIdAndUserId(Long circleId, Long userId);
    boolean existsByCircleIdAndUserId(Long circleId, Long userId);
}
