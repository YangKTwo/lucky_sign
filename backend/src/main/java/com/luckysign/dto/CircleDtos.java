package com.luckysign.dto;

import java.util.List;

public class CircleDtos {
    public record MemberBrief(
            Long userId,
            String nickname,
            String avatarUrl,
            boolean assistant
    ) {
    }

    public record MembersResponse(List<MemberBrief> members) {
    }

    public record CircleMeResponse(
            Long id,
            String name,
            String inviteCode,
            Integer memberCount,
            Integer maxMembers
    ) {
    }
}
