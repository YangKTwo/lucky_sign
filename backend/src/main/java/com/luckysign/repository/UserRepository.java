package com.luckysign.repository;

import com.luckysign.domain.UserRole;
import com.luckysign.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByEmail(String email);
    boolean existsByEmail(String email);
    List<User> findByTagNot(com.luckysign.domain.UserTag tag);

    @Query("SELECT u.tokenVersion FROM User u WHERE u.id = :userId")
    Optional<Long> findTokenVersionById(@Param("userId") Long userId);

    @Query("SELECT u.role FROM User u WHERE u.id = :userId")
    Optional<UserRole> findRoleById(@Param("userId") Long userId);

    @Query("SELECT u.enabled FROM User u WHERE u.id = :userId")
    Optional<Boolean> findEnabledById(@Param("userId") Long userId);

    @Modifying
    @Query("UPDATE User u SET u.tokenVersion = u.tokenVersion + 1 WHERE u.id = :userId")
    int incrementTokenVersion(@Param("userId") Long userId);
}
