package com.luckysign.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public class AuthDtos {
    public record RegisterRequest(
            @NotBlank @Size(max = 32) String nickname,
            @NotBlank @Email String email,
            @NotBlank @Size(min = 6, max = 64) String password
    ) {
    }

    public record LoginRequest(
            @NotBlank @Email String email,
            @NotBlank String password
    ) {
    }

    public record AuthResponse(String token, UserProfileResponse profile) {
    }

    public record UserProfileResponse(
            Long id,
            String nickname,
            String email,
            Integer points,
            String title,
            Integer streakDays,
            Integer totalCompletedDays,
            String tag,
            String role
    ) {
    }

    public record UpdateProfileRequest(
            @Size(max = 32) String nickname,
            @Size(min = 6, max = 64) String password
    ) {
    }
}
