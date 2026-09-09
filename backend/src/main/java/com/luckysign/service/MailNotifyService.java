package com.luckysign.service;

import com.luckysign.config.AppProperties;
import com.luckysign.entity.EmailLog;
import com.luckysign.entity.User;
import com.luckysign.repository.EmailLogRepository;
import com.luckysign.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class MailNotifyService {
    private static final Logger log = LoggerFactory.getLogger(MailNotifyService.class);

    private final JavaMailSender mailSender;
    private final EmailLogRepository emailLogRepository;
    private final UserRepository userRepository;
    private final AppProperties appProperties;

    public MailNotifyService(JavaMailSender mailSender,
                             EmailLogRepository emailLogRepository,
                             UserRepository userRepository,
                             AppProperties appProperties) {
        this.mailSender = mailSender;
        this.emailLogRepository = emailLogRepository;
        this.userRepository = userRepository;
        this.appProperties = appProperties;
    }

    @Async
    public void sendDailyReminders() {
        List<User> users = userRepository.findByTagNot(com.luckysign.domain.UserTag.DORMANT);
        for (User user : users) {
            send(user.getEmail(), "今日幸运签已到", "今日幸运签已到，打开App查看！🍀");
        }
    }

    @Async
    public void sendWarning(String email, String subject, String content) {
        send(email, subject, content);
    }

    private void send(String to, String subject, String content) {
        EmailLog emailLog = new EmailLog();
        emailLog.setToEmail(to);
        emailLog.setSubject(subject);
        emailLog.setContent(content);
        try {
            if (!appProperties.getMail().isEnabled()) {
                log.info("[MAIL-MOCK] to={} subject={} content={}", to, subject, content);
                emailLog.setStatus("MOCK");
            } else {
                SimpleMailMessage message = new SimpleMailMessage();
                message.setFrom(appProperties.getMail().getFrom());
                message.setTo(to);
                message.setSubject(subject);
                message.setText(content);
                mailSender.send(message);
                emailLog.setStatus("SUCCESS");
            }
        } catch (Exception e) {
            emailLog.setStatus("FAIL");
            emailLog.setErrorMessage(e.getMessage());
            log.warn("Mail failed to={}: {}", to, e.getMessage());
        }
        emailLogRepository.save(emailLog);
    }
}
