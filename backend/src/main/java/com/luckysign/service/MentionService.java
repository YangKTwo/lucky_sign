package com.luckysign.service;

import com.luckysign.entity.CircleMember;
import com.luckysign.entity.User;
import com.luckysign.repository.CircleMemberRepository;
import com.luckysign.repository.UserRepository;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

@Service
public class MentionService {
    public static final String ASSISTANT_DISPLAY_NAME = "石桥头第一AI";

    private final CircleMemberRepository circleMemberRepository;
    private final UserRepository userRepository;
    private final AiAssistantService aiAssistantService;

    public MentionService(CircleMemberRepository circleMemberRepository,
                          UserRepository userRepository,
                          AiAssistantService aiAssistantService) {
        this.circleMemberRepository = circleMemberRepository;
        this.userRepository = userRepository;
        this.aiAssistantService = aiAssistantService;
    }

    public List<String> assistantMentionTokens() {
        Set<String> tokens = new HashSet<>();
        tokens.add("@助手");
        tokens.add("@" + ASSISTANT_DISPLAY_NAME);
        String configured = aiAssistantService.mentionToken();
        if (configured != null && !configured.isBlank()) {
            tokens.add(configured.trim());
        }
        return tokens.stream()
                .sorted(Comparator.comparingInt(String::length).reversed())
                .toList();
    }

    public boolean mentionsAssistant(String content) {
        if (content == null || content.isBlank()) {
            return false;
        }
        for (String token : assistantMentionTokens()) {
            if (content.contains(token)) {
                return true;
            }
        }
        return false;
    }

    public String stripAssistantMentions(String content) {
        String q = content == null ? "" : content;
        for (String token : assistantMentionTokens()) {
            q = q.replace(token, " ");
        }
        q = q.trim().replaceAll("\\s+", " ");
        return q;
    }

    public Map<String, Long> nicknameToUserId(Long circleId) {
        List<CircleMember> members = circleMemberRepository.findByCircleId(circleId);
        if (members.isEmpty()) {
            return Map.of();
        }
        Map<Long, User> users = userRepository.findAllById(members.stream().map(CircleMember::getUserId).toList())
                .stream()
                .collect(java.util.stream.Collectors.toMap(User::getId, u -> u, (a, b) -> a, LinkedHashMap::new));
        Map<String, Long> map = new LinkedHashMap<>();
        for (CircleMember m : members) {
            User u = users.get(m.getUserId());
            if (u == null || u.getNickname() == null || u.getNickname().isBlank()) {
                continue;
            }
            map.put(u.getNickname().trim(), u.getId());
        }
        return map;
    }

    /** 解析正文中的 @昵称，按昵称长度优先匹配，避免短名抢长名。 */
    public List<Long> parseMentionedUserIds(String content, Long circleId, Long excludeUserId) {
        if (content == null || content.isBlank()) {
            return List.of();
        }
        Map<String, Long> nickMap = nicknameToUserId(circleId);
        List<String> names = new ArrayList<>(nickMap.keySet());
        names.sort(Comparator.comparingInt(String::length).reversed());
        Set<Long> hit = new HashSet<>();
        boolean[] used = new boolean[content.length()];
        for (String name : names) {
            String token = "@" + name;
            int from = 0;
            while (from < content.length()) {
                int idx = content.indexOf(token, from);
                if (idx < 0) {
                    break;
                }
                int end = idx + token.length();
                if (!rangeUsed(used, idx, end) && isMentionBoundary(content, end)) {
                    Long uid = nickMap.get(name);
                    if (uid != null && (excludeUserId == null || !uid.equals(excludeUserId))) {
                        hit.add(uid);
                    }
                    markUsed(used, idx, end);
                }
                from = idx + 1;
            }
        }
        return List.copyOf(hit);
    }

    /** @昵称 后应为结尾或空白/标点，避免短昵称误伤。 */
    private static boolean isMentionBoundary(String content, int end) {
        if (end >= content.length()) {
            return true;
        }
        char c = content.charAt(end);
        if (Character.isWhitespace(c)) {
            return true;
        }
        return switch (c) {
            case ',', '.', '!', '?', ';', ':',
                    '，', '。', '！', '？', '；', '：',
                    '、', ')', '）', ']', '】', '}', '"', '\'',
                    '\n', '\r', '\t' -> true;
            default -> false;
        };
    }

    public String serializeMentionIds(List<Long> ids) {
        if (ids == null || ids.isEmpty()) {
            return null;
        }
        return ids.stream().map(String::valueOf).reduce((a, b) -> a + "," + b).orElse(null);
    }

    public List<Long> deserializeMentionIds(String raw) {
        if (raw == null || raw.isBlank()) {
            return List.of();
        }
        List<Long> out = new ArrayList<>();
        for (String part : raw.split(",")) {
            String p = part.trim();
            if (p.isEmpty()) {
                continue;
            }
            try {
                out.add(Long.parseLong(p));
            } catch (NumberFormatException ignored) {
                // skip
            }
        }
        return out;
    }

    private static boolean rangeUsed(boolean[] used, int start, int end) {
        for (int i = start; i < end && i < used.length; i++) {
            if (used[i]) {
                return true;
            }
        }
        return false;
    }

    private static void markUsed(boolean[] used, int start, int end) {
        for (int i = start; i < end && i < used.length; i++) {
            used[i] = true;
        }
    }
}
