package com.luckysign.config;

import com.luckysign.domain.*;
import com.luckysign.entity.*;
import com.luckysign.repository.*;
import com.luckysign.service.TitleService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
public class DataSeeder implements CommandLineRunner {
    private static final Logger log = LoggerFactory.getLogger(DataSeeder.class);

    private final UserRepository userRepository;
    private final CircleRepository circleRepository;
    private final CircleMemberRepository circleMemberRepository;
    private final TaskItemRepository taskItemRepository;
    private final FortuneCopyRepository fortuneCopyRepository;
    private final PasswordEncoder passwordEncoder;
    private final TitleService titleService;

    public DataSeeder(UserRepository userRepository,
                      CircleRepository circleRepository,
                      CircleMemberRepository circleMemberRepository,
                      TaskItemRepository taskItemRepository,
                      FortuneCopyRepository fortuneCopyRepository,
                      PasswordEncoder passwordEncoder,
                      TitleService titleService) {
        this.userRepository = userRepository;
        this.circleRepository = circleRepository;
        this.circleMemberRepository = circleMemberRepository;
        this.taskItemRepository = taskItemRepository;
        this.fortuneCopyRepository = fortuneCopyRepository;
        this.passwordEncoder = passwordEncoder;
        this.titleService = titleService;
    }

    @Override
    @Transactional
    public void run(String... args) {
        seedCircleAndAdmin();
        seedTasks();
        seedFortunes();
    }

    private void seedCircleAndAdmin() {
        Circle circle = circleRepository.findFirstByOrderByIdAsc().orElseGet(() -> {
            Circle c = new Circle();
            c.setName("今日幸运签小圈子");
            c.setOwnerId(0L);
            c.setMaxMembers(10);
            c.setMemberCount(0);
            c.setStatus("ACTIVE");
            return circleRepository.save(c);
        });

        String adminPassword = System.getenv("ADMIN_PASSWORD");
        if (adminPassword == null || adminPassword.isBlank()) {
            if (userRepository.findByEmail("admin@luckysign.local").isEmpty()) {
                log.warn("Skip admin seed: set ADMIN_PASSWORD to create admin@luckysign.local");
            }
            return;
        }
        User admin = userRepository.findByEmail("admin@luckysign.local").orElseGet(() -> {
            User u = new User();
            u.setEmail("admin@luckysign.local");
            u.setNickname("管理员");
            u.setPasswordHash(passwordEncoder.encode(adminPassword));
            u.setRole(UserRole.ADMIN);
            u.setTitle(titleService.resolve(0));
            u.setTag(UserTag.NONE);
            return userRepository.save(u);
        });

        if (circle.getOwnerId() == null || circle.getOwnerId() == 0L) {
            circle.setOwnerId(admin.getId());
            circleRepository.save(circle);
        }

        if (!circleMemberRepository.existsByCircleIdAndUserId(circle.getId(), admin.getId())) {
            CircleMember m = new CircleMember();
            m.setCircleId(circle.getId());
            m.setUserId(admin.getId());
            m.setRole(MemberRole.OWNER);
            circleMemberRepository.save(m);
            circle.setMemberCount(circle.getMemberCount() + 1);
            circleRepository.save(circle);
        }
        log.info("Seed admin ready: admin@luckysign.local");
    }

    private void seedTasks() {
        if (taskItemRepository.countByEnabledTrue() > 0) {
            return;
        }
        String[] simple = {
                "对着镜子夸自己1分钟", "给自己泡一杯喜欢的饮料", "听一首让你开心的歌",
                "整理桌面5分钟", "给朋友发一句早安", "做10个开合跳", "写下一件今天感恩的事",
                "伸懒腰并深呼吸10次"
        };
        String[] medium = {
                "给3年没联系的同学发条消息", "步行去买一杯咖啡/奶茶", "读一篇短文并分享一句摘录",
                "学一个新的小技能10分钟", "给家人打个电话", "清理手机相册删除20张图",
                "写一封给未来自己的短信", "主动帮室友/家人做一件小事"
        };
        String[] mediumHard = {
                "今天做一件一直拖延的事", "公开分享一个小目标", "连续专注工作/学习45分钟",
                "尝试一道没做过的菜或新口味", "整理一个拖延很久的文件夹",
                "把一件闲置物品送人或卖掉", "早睡，23:30前上床", "完成一次30分钟运动"
        };
        String[] hard = {
                "主动帮助一个陌生人", "在朋友面前做一件你通常不好意思做的事",
                "当天内完成一份被拖很久的文档/作业", "去一个从没去过的地方逛半小时",
                "给不太熟的朋友送一句真诚夸奖", "坚持一整天少刷短视频",
                "当众分享今日幸运签内容", "为圈子贡献一条新任务创意"
        };
        saveTasks(simple, TaskDifficulty.SIMPLE);
        saveTasks(medium, TaskDifficulty.MEDIUM);
        saveTasks(mediumHard, TaskDifficulty.MEDIUM_HARD);
        saveTasks(hard, TaskDifficulty.HARD);
        log.info("Seeded tasks: {}", taskItemRepository.count());
    }

    private void saveTasks(String[] contents, TaskDifficulty difficulty) {
        for (String c : contents) {
            TaskItem t = new TaskItem();
            t.setContent(c);
            t.setDifficulty(difficulty);
            t.setEnabled(true);
            taskItemRepository.save(t);
        }
    }

    private void seedFortunes() {
        if (fortuneCopyRepository.countByEnabledTrue() > 0) {
            return;
        }
        saveFortune(FortuneLevel.SS, "今日欧皇附体！");
        saveFortune(FortuneLevel.SS, "传说级运气上线");
        saveFortune(FortuneLevel.S, "运气爆棚！");
        saveFortune(FortuneLevel.S, "好事正在排队");
        saveFortune(FortuneLevel.A, "不错，挺顺");
        saveFortune(FortuneLevel.A, "小确幸靠近中");
        saveFortune(FortuneLevel.B, "平平无奇的一天");
        saveFortune(FortuneLevel.B, "稳住，能过");
        saveFortune(FortuneLevel.C, "今日非酋认证…");
        saveFortune(FortuneLevel.C, "霉运绝缘胶带请自备");
        log.info("Seeded fortune copies: {}", fortuneCopyRepository.count());
    }

    private void saveFortune(FortuneLevel level, String content) {
        FortuneCopy c = new FortuneCopy();
        c.setLevel(level);
        c.setContent(content);
        c.setEnabled(true);
        fortuneCopyRepository.save(c);
    }
}
