package com.luckysign.service;

import com.aliyun.oss.OSS;
import com.aliyun.oss.OSSClientBuilder;
import com.luckysign.common.BizException;
import com.luckysign.config.AppProperties;
import jakarta.annotation.PreDestroy;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Set;
import java.util.UUID;

@Service
public class FileStorageService {
    private static final Set<String> ALLOWED = Set.of("image/jpeg", "image/png", "image/jpg", "image/webp");
    private final AppProperties appProperties;
    private final Path localRoot;
    private final OSS ossClient;
    private final boolean useOss;

    public FileStorageService(AppProperties appProperties) throws IOException {
        this.appProperties = appProperties;
        this.localRoot = Paths.get(appProperties.getUpload().getDir()).toAbsolutePath().normalize();
        Files.createDirectories(this.localRoot);

        AppProperties.Oss oss = appProperties.getOss();
        this.useOss = oss.isEnabled()
                && notBlank(oss.getEndpoint())
                && notBlank(oss.getAccessKeyId())
                && notBlank(oss.getAccessKeySecret())
                && notBlank(oss.getBucket());
        if (this.useOss) {
            this.ossClient = new OSSClientBuilder().build(
                    normalizeEndpoint(oss.getEndpoint()),
                    oss.getAccessKeyId(),
                    oss.getAccessKeySecret());
        } else {
            this.ossClient = null;
        }
    }

    public String save(MultipartFile file) {
        String contentType = resolveContentType(file);
        if (contentType == null || !ALLOWED.contains(contentType)) {
            throw new BizException("仅支持 jpg/png/webp 图片");
        }
        String ext = switch (contentType) {
            case "image/png" -> ".png";
            case "image/webp" -> ".webp";
            default -> ".jpg";
        };
        String filename = UUID.randomUUID() + ext;
        if (useOss) {
            return saveToOss(file, filename, contentType);
        }
        return saveLocal(file, filename);
    }

    private String saveToOss(MultipartFile file, String filename, String contentType) {
        AppProperties.Oss oss = appProperties.getOss();
        String prefix = oss.getDirPrefix() == null ? "" : oss.getDirPrefix();
        if (!prefix.isEmpty() && !prefix.endsWith("/")) {
            prefix = prefix + "/";
        }
        String key = prefix + filename;
        try (InputStream in = file.getInputStream()) {
            var meta = new com.aliyun.oss.model.ObjectMetadata();
            meta.setContentType(contentType);
            meta.setContentLength(file.getSize());
            ossClient.putObject(oss.getBucket(), key, in, meta);
            return publicUrl(key);
        } catch (Exception e) {
            throw new BizException("图片上传 OSS 失败");
        }
    }

    private String publicUrl(String key) {
        AppProperties.Oss oss = appProperties.getOss();
        String base = oss.getPublicBaseUrl();
        if (notBlank(base)) {
            return trimSlash(base) + "/" + key;
        }
        String endpoint = normalizeEndpoint(oss.getEndpoint()).replace("https://", "").replace("http://", "");
        return "https://" + oss.getBucket() + "." + endpoint + "/" + key;
    }

    private String saveLocal(MultipartFile file, String filename) {
        try {
            Path target = localRoot.resolve(filename);
            file.transferTo(target);
            return "/uploads/" + filename;
        } catch (IOException e) {
            throw new BizException("图片保存失败");
        }
    }

    private String resolveContentType(MultipartFile file) {
        String ct = file.getContentType();
        if (ct != null) {
            ct = ct.toLowerCase().split(";")[0].trim();
            if ("image/jpg".equals(ct)) {
                ct = "image/jpeg";
            }
            if (ALLOWED.contains(ct)) {
                return ct;
            }
        }
        String name = file.getOriginalFilename();
        if (name == null) {
            return null;
        }
        String lower = name.toLowerCase();
        if (lower.endsWith(".png")) {
            return "image/png";
        }
        if (lower.endsWith(".webp")) {
            return "image/webp";
        }
        if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) {
            return "image/jpeg";
        }
        return null;
    }

    private static String normalizeEndpoint(String endpoint) {
        String e = endpoint.trim();
        if (!e.startsWith("http://") && !e.startsWith("https://")) {
            e = "https://" + e;
        }
        return e;
    }

    private static boolean notBlank(String s) {
        return s != null && !s.isBlank();
    }

    private static String trimSlash(String s) {
        return s.endsWith("/") ? s.substring(0, s.length() - 1) : s;
    }

    @PreDestroy
    public void destroy() {
        if (ossClient != null) {
            ossClient.shutdown();
        }
    }
}
