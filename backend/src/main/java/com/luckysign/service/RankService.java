package com.luckysign.service;

import com.luckysign.dto.RankDtos;
import com.luckysign.entity.Circle;
import com.luckysign.entity.CircleDailyStar;
import com.luckysign.entity.CircleMember;
import com.luckysign.entity.DailyDraw;
import com.luckysign.entity.User;
import com.luckysign.repository.CircleDailyStarRepository;
import com.luckysign.repository.CircleMemberRepository;
import com.luckysign.repository.CircleRepository;
import com.luckysign.repository.DailyDrawRepository;
import com.luckysign.repository.UserRepository;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
public class RankService {
    private final CircleRepository circleRepository;
    private final CircleMemberRepository circleMemberRepository;
    private final UserRepository userRepository;
    private final DailyDrawRepository dailyDrawRepository;
    private final CircleDailyStarRepository circleDailyStarRepository;
    private final DrawService drawService;

    public RankService(CircleRepository circleRepository,
                       CircleMemberRepository circleMemberRepository,
                       UserRepository userRepository,
                       DailyDrawRepository dailyDrawRepository,
                       CircleDailyStarRepository circleDailyStarRepository,
                       DrawService drawService) {
        this.circleRepository = circleRepository;
        this.circleMemberRepository = circleMemberRepository;
        this.userRepository = userRepository;
        this.dailyDrawRepository = dailyDrawRepository;
        this.circleDailyStarRepository = circleDailyStarRepository;
        this.drawService = drawService;
    }

    public RankDtos.RankingResponse ranking() {
        Circle circle = circleRepository.findFirstByOrderByIdAsc().orElseThrow();
        LocalDate today = drawService.today();
        List<CircleMember> members = circleMemberRepository.findByCircleId(circle.getId());
        Map<Long, User> users = userRepository.findAllById(members.stream().map(CircleMember::getUserId).toList())
                .stream().collect(Collectors.toMap(User::getId, Function.identity()));
        Map<Long, DailyDraw> draws = dailyDrawRepository.findByDrawDate(today).stream()
                .collect(Collectors.toMap(DailyDraw::getUserId, Function.identity(), (a, b) -> a));
        Optional<CircleDailyStar> star = circleDailyStarRepository.findByCircleIdAndStarDate(circle.getId(), today);

        List<RankDtos.MemberStatus> list = members.stream()
                .map(m -> users.get(m.getUserId()))
                .filter(u -> u != null)
                .map(u -> {
                    DailyDraw d = draws.get(u.getId());
                    String todayStatus = d == null ? "NONE" : d.getStatus().name();
                    boolean isStar = star.map(s -> s.getUserId().equals(u.getId())).orElse(false);
                    return new RankDtos.MemberStatus(
                            u.getId(),
                            u.getNickname(),
                            u.getTitle(),
                            u.getPoints(),
                            u.getStreakDays(),
                            u.getTag().name(),
                            todayStatus,
                            isStar
                    );
                })
                .toList();

        List<RankDtos.MemberStatus> byPoints = list.stream()
                .sorted(Comparator.comparing(RankDtos.MemberStatus::points).reversed())
                .toList();
        List<RankDtos.MemberStatus> byStreak = list.stream()
                .sorted(Comparator.comparing(RankDtos.MemberStatus::streakDays).reversed())
                .toList();

        RankDtos.LuckyStarInfo luckyStarInfo = star
                .map(s -> {
                    User u = users.get(s.getUserId());
                    return new RankDtos.LuckyStarInfo(s.getUserId(), u == null ? "" : u.getNickname());
                })
                .orElse(null);

        return new RankDtos.RankingResponse(byPoints, byStreak, luckyStarInfo);
    }
}
