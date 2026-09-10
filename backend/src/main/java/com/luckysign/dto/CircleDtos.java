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
}
