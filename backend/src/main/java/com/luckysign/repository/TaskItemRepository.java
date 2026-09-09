package com.luckysign.repository;

import com.luckysign.domain.TaskDifficulty;
import com.luckysign.entity.TaskItem;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface TaskItemRepository extends JpaRepository<TaskItem, Long> {
    List<TaskItem> findByDifficultyAndEnabledTrue(TaskDifficulty difficulty);
    long countByEnabledTrue();
}
