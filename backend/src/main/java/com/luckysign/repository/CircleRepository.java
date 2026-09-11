package com.luckysign.repository;

import com.luckysign.entity.Circle;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface CircleRepository extends JpaRepository<Circle, Long> {
    Optional<Circle> findFirstByOrderByIdAsc();

    Optional<Circle> findByInviteCode(String inviteCode);

    boolean existsByInviteCode(String inviteCode);

    @Modifying
    @Query("UPDATE Circle c SET c.memberCount = c.memberCount + 1 WHERE c.id = :circleId AND (c.maxMembers IS NULL OR c.memberCount < c.maxMembers)")
    int incrementMemberCount(@Param("circleId") Long circleId);

    @Modifying
    @Query("UPDATE Circle c SET c.memberCount = GREATEST(0, c.memberCount - 1) WHERE c.id = :circleId")
    int decrementMemberCount(@Param("circleId") Long circleId);
}
