package com.luckysign.repository;

import com.luckysign.domain.FortuneLevel;
import com.luckysign.entity.FortuneCopy;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface FortuneCopyRepository extends JpaRepository<FortuneCopy, Long> {
    List<FortuneCopy> findByLevelAndEnabledTrue(FortuneLevel level);
    long countByEnabledTrue();
}
