package com.luckysign.repository;

import com.luckysign.entity.CheckinRating;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface CheckinRatingRepository extends JpaRepository<CheckinRating, Long> {
    Optional<CheckinRating> findByCheckinIdAndRaterUserId(Long checkinId, Long raterUserId);

    List<CheckinRating> findByCheckinId(Long checkinId);

    List<CheckinRating> findByCheckinIdIn(Collection<Long> checkinIds);

    @Query("select r.targetUserId, avg(r.score), count(r) from CheckinRating r group by r.targetUserId")
    List<Object[]> avgByTargetUser();
}
