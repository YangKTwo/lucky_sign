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
    private WebApp web = new WebApp();
    private Oss oss = new Oss();
    private Ai ai = new Ai();
    private Mail mail = new Mail();
    private String timezone = "Asia/Shanghai";

    @Getter
    @Setter
    public static class Jwt {
        private String secret;
        private String secretPrevious;
        private int expireDays = 7;
        private int accessTokenMinutes = 30;
        private int refreshTokenDays = 30;
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
    public static class WebApp {
        /** Flutter Web 构建产物目录（部署到 /app/） */
        private String dir = "./webapp";
    }

    @Getter
    @Setter
    public static class Oss {
        /** 为 true 且密钥齐全时走阿里云 OSS，否则本地 uploads */
        private boolean enabled = false;
        private String endpoint = "";
        private String accessKeyId = "";
        private String accessKeySecret = "";
        private String bucket = "";
        /** 对象前缀，如 lucky-sign/ */
        private String dirPrefix = "lucky-sign/";
        /** 可选：CDN/自定义域名，不含尾斜杠。为空则用 https://{bucket}.{endpoint}/{key} */
        private String publicBaseUrl = "";
    }

    @Getter
    @Setter
    public static class Ai {
        private boolean enabled = false;
        private String apiKey = "";
        private String model = "qwen-plus";
        private String baseUrl = "https://dashscope.aliyuncs.com/compatible-mode/v1";
        /** 触发助手的关键词，默认 @助手 */
        private String mention = "@助手";
        private String systemPrompt = "你是「石桥头第一AI」，「今日幸运签」小圈子的社区助手，语气轻松友好，回答简洁，用中文。";
    }

    @Getter
    @Setter
    public static class Mail {
        private boolean enabled = false;
        private String from = "lucky-sign@example.com";
    }
}
