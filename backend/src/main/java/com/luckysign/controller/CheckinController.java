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
    public ApiResponse<CheckinDtos.TodayResponse> today(@RequestParam(required = false) Long circleId) {
        Long userId = AuthSupport.currentUserId();
        Long resolvedCircleId = circleAccessGuard.requireMemberAndResolve(circleId, userId);
        return ApiResponse.ok(checkinService.today(resolvedCircleId, userId));
    }

    @PostMapping(value = "/complete", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ApiResponse<CheckinDtos.TodayResponse> complete(
            @RequestParam(required = false) Long circleId,
            @RequestParam(value = "text", required = false) String text,
            @RequestParam(value = "image", required = false) MultipartFile image) {
        Long userId = AuthSupport.currentUserId();
        Long resolvedCircleId = circleAccessGuard.requireMemberAndResolve(circleId, userId);
        return ApiResponse.ok(checkinService.complete(resolvedCircleId, userId, text, image));
    }

    @GetMapping("/history")
    public ApiResponse<CheckinDtos.HistoryResponse> history(@RequestParam(required = false) Long circleId) {
        Long userId = AuthSupport.currentUserId();
        circleAccessGuard.requireMemberAndResolve(circleId, userId);
        return ApiResponse.ok(checkinService.history(userId));
    }

    @GetMapping("/calendar")
    public ApiResponse<CheckinDtos.CalendarResponse> calendar(
            @RequestParam(required = false) Long circleId,
            @RequestParam(defaultValue = "84") int days) {
        Long userId = AuthSupport.currentUserId();
        circleAccessGuard.requireMemberAndResolve(circleId, userId);
        return ApiResponse.ok(checkinService.calendar(userId, days));
    }

    @GetMapping("/streak")
    public ApiResponse<Integer> streak(@RequestParam(required = false) Long circleId) {
        Long userId = AuthSupport.currentUserId();
        Long resolvedCircleId = circleAccessGuard.requireMemberAndResolve(circleId, userId);
        return ApiResponse.ok(checkinService.today(resolvedCircleId, userId).streakDays());
    }

    @PostMapping("/{checkinId}/rate")
    public ApiResponse<RatingDtos.RatingSummary> rate(
            @RequestParam(required = false) Long circleId,
            @PathVariable Long checkinId,
            @RequestBody RatingDtos.RateRequest request) {
        Long userId = AuthSupport.currentUserId();
        Long resolvedCircleId = circleAccessGuard.requireMemberAndResolve(circleId, userId);
        return ApiResponse.ok(ratingService.rate(resolvedCircleId, userId, checkinId, request.score()));
    }

    @GetMapping("/{checkinId}")
    public ApiResponse<RatingDtos.CheckinDetail> detail(
            @RequestParam(required = false) Long circleId,
            @PathVariable Long checkinId) {
        Long userId = AuthSupport.currentUserId();
        Long resolvedCircleId = circleAccessGuard.requireMemberAndResolve(circleId, userId);
        return ApiResponse.ok(ratingService.detail(resolvedCircleId, checkinId, userId));
    }
}
