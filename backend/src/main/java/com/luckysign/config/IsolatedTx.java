package com.luckysign.config;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * 每条任务独立事务（REQUIRES_NEW），避免定时批处理一人失败拖垮全员。
 */
@Component
public class IsolatedTx {
    private final TransactionTemplate template;

    @Autowired
    public IsolatedTx(PlatformTransactionManager transactionManager) {
        TransactionTemplate t = new TransactionTemplate(transactionManager);
        t.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
        this.template = t;
    }

    /** 单测用：不经事务管理器，直接执行。 */
    public IsolatedTx() {
        this.template = null;
    }

    public void run(Runnable work) {
        if (template == null) {
            work.run();
            return;
        }
        template.executeWithoutResult(status -> work.run());
    }
}
