package com.luckysign.common;

import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.util.function.Supplier;

/**
 * 把单条抽签/结算放到独立事务里，一条失败不连带回滚整批。
 */
@Component
public class IsolatedTx {
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void run(Runnable action) {
        action.run();
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public <T> T call(Supplier<T> action) {
        return action.get();
    }
}
