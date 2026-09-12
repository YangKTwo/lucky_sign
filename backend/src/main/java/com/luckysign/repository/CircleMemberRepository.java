package com.luckysign.repository;

import com.luckysign.entity.CircleMember;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface CircleMemberRepository extends JpaRepository<CircleMember, Long> {
    List<CircleMember> findByCircleId(Long circleId);
    Optional<CircleMember> findByCircleIdAndUserId(Long circleId, Long userId);
    boolean existsByCircleIdAndUserId(Long circleId, Long userId);

    List<CircleMember> findByUserId(Long userId);

    @Query("SELECT cm.circleId FROM CircleMember cm WHERE cm.userId = :userId ORDER BY cm.id ASC")
    List<Long> findCircleIdsByUserId(@Param("userId") Long userId);

    @Query("SELECT cm.circleId FROM CircleMember cm WHERE cm.userId = :userId ORDER BY cm.id ASC LIMIT 1")
    Optional<Long> findFirstCircleIdByUserId(@Param("userId") Long userId);
}
