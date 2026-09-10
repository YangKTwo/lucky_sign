package com.luckysign.controller;

import com.luckysign.common.ApiResponse;
import com.luckysign.dto.CheckinDtos;
import com.luckysign.dto.RatingDtos;
import com.luckysign.security.AuthSupport;
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

    public CheckinController(CheckinService checkinService, RatingService ratingService) {
        this.checkinService = checkinService;
        this.ratingService = ratingService;
    }

    @GetMapping("/today")
    public ApiResponse<CheckinDtos.TodayResponse> today() {
        return ApiResponse.ok(checkinService.today(AuthSupport.currentUserId()));
    }

    @PostMapping(value = "/complete", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ApiResponse<CheckinDtos.TodayResponse> complete(
            @RequestParam(value = "text", required = false) String text,
            @RequestParam(value = "image", required = false) MultipartFile image) {
        return ApiResponse.ok(checkinService.complete(AuthSupport.currentUserId(), text, image));
    }

    @GetMapping("/history")
    public ApiResponse<CheckinDtos.HistoryResponse> history() {
        return ApiResponse.ok(checkinService.history(AuthSupport.currentUserId()));
    }

    @GetMapping("/streak")
    public ApiResponse<Integer> streak() {
        return ApiResponse.ok(checkinService.today(AuthSupport.currentUserId()).streakDays());
    }

    @PostMapping("/{checkinId}/rate")
    public ApiResponse<RatingDtos.RatingSummary> rate(
            @PathVariable Long checkinId,
            @RequestBody RatingDtos.RateRequest request) {
        return ApiResponse.ok(ratingService.rate(AuthSupport.currentUserId(), checkinId, request.score()));
    }
}
