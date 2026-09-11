package com.luckysign.controller;

import com.luckysign.common.ApiResponse;
import com.luckysign.dto.CheckinDtos;
import com.luckysign.dto.RatingDtos;
import com.luckysign.security.AuthSupport;
import com.luckysign.security.CircleAccessGuard;
import com.luckysign.service.CheckinService;
import com.luckysign.service.RatingService;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/checkin")
public class CheckinController {
    private final CheckinService checkinService;
    private final RatingService ratingService;
    private final CircleAccessGuard circleAccessGuard;

    public CheckinController(CheckinService checkinService, RatingService ratingService,
                             CircleAccessGuard circleAccessGuard) {
        this.checkinService = checkinService;
        this.ratingService = ratingService;
        this.circleAccessGuard = circleAccessGuard;
    }

    @GetMapping("/today")
    public ApiResponse<CheckinDtos.TodayResponse> today() {
        Long userId = AuthSupport.currentUserId();
        circleAccessGuard.requireMember(userId);
        return ApiResponse.ok(checkinService.today(userId));
    }

    @PostMapping(value = "/complete", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ApiResponse<CheckinDtos.TodayResponse> complete(
            @RequestParam(value = "text", required = false) String text,
            @RequestParam(value = "image", required = false) MultipartFile image) {
        Long userId = AuthSupport.currentUserId();
        circleAccessGuard.requireMember(userId);
        return ApiResponse.ok(checkinService.complete(userId, text, image));
    }

    @GetMapping("/history")
    public ApiResponse<CheckinDtos.HistoryResponse> history() {
        Long userId = AuthSupport.currentUserId();
        circleAccessGuard.requireMember(userId);
        return ApiResponse.ok(checkinService.history(userId));
    }

    @GetMapping("/calendar")
    public ApiResponse<CheckinDtos.CalendarResponse> calendar(
            @RequestParam(defaultValue = "84") int days) {
        Long userId = AuthSupport.currentUserId();
        circleAccessGuard.requireMember(userId);
        return ApiResponse.ok(checkinService.calendar(userId, days));
    }

    @GetMapping("/streak")
    public ApiResponse<Integer> streak() {
        Long userId = AuthSupport.currentUserId();
        circleAccessGuard.requireMember(userId);
        return ApiResponse.ok(checkinService.today(userId).streakDays());
    }

    @PostMapping("/{checkinId}/rate")
    public ApiResponse<RatingDtos.RatingSummary> rate(
            @PathVariable Long checkinId,
            @RequestBody RatingDtos.RateRequest request) {
        Long userId = AuthSupport.currentUserId();
        circleAccessGuard.requireMember(userId);
        return ApiResponse.ok(ratingService.rate(userId, checkinId, request.score()));
    }

    @GetMapping("/{checkinId}")
    public ApiResponse<RatingDtos.CheckinDetail> detail(@PathVariable Long checkinId) {
        Long userId = AuthSupport.currentUserId();
        circleAccessGuard.requireMember(userId);
        return ApiResponse.ok(ratingService.detail(checkinId, userId));
    }
}
