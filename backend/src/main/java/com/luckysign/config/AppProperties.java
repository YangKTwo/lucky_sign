package com.luckysign.config;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Getter
@Setter
@Component
@ConfigurationProperties(prefix = "app")
public class AppProperties {
    private Jwt jwt = new Jwt();
    private Upload upload = new Upload();
    private Download download = new Download();
    private Mail mail = new Mail();
    private String timezone = "Asia/Shanghai";

    @Getter
    @Setter
    public static class Jwt {
        private String secret;
        private int expireDays = 7;
    }

    @Getter
    @Setter
    public static class Upload {
        private String dir = "./uploads";
    }

    @Getter
    @Setter
    public static class Download {
        private String dir = "./downloads";
    }

    @Getter
    @Setter
    public static class Mail {
        private boolean enabled = false;
        private String from = "lucky-sign@example.com";
    }
}
