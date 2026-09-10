package com.luckysign.service;

import com.aliyun.oss.OSS;
import com.aliyun.oss.OSSClientBuilder;
import com.aliyun.oss.OSSException;
import com.luckysign.common.BizException;
import com.luckysign.config.AppProperties;
import jakarta.annotation.PreDestroy;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;

@Service
public class FileStorageService {
    private static final Logger log = LoggerFactory.getLogger(FileStorageService.class);
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
            String endpoint = normalizeEndpoint(oss.getEndpoint());
            this.ossClient = new OSSClientBuilder().build(
                    endpoint,
                    oss.getAccessKeyId().trim(),
                    oss.getAccessKeySecret().trim());
            log.info("OSS enabled bucket={} endpoint={}", oss.getBucket(), endpoint);
        } else {
            this.ossClient = null;
            log.info("OSS disabled, using local upload dir={}", this.localRoot);
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
        String prefix = oss.getDirPrefix() == null ? "" : oss.getDirPrefix().trim();
        if (!prefix.isEmpty() && !prefix.endsWith("/")) {
            prefix = prefix + "/";
        }
        String key = prefix + filename;
        long size = file.getSize();
        try (InputStream in = file.getInputStream()) {
            var meta = new com.aliyun.oss.model.ObjectMetadata();
            meta.setContentType(contentType);
            if (size > 0) {
                meta.setContentLength(size);
            }
            ossClient.putObject(oss.getBucket().trim(), key, in, meta);
            return publicUrl(key);
        } catch (OSSException e) {
            log.warn("OSS putObject failed code={} msg={} requestId={} hostId={}",
                    e.getErrorCode(), e.getErrorMessage(), e.getRequestId(), e.getHostId());
            String hint = e.getErrorMessage() == null ? "" : e.getErrorMessage();
            if (hint.toLowerCase(Locale.ROOT).contains("endpoint")
                    || hint.contains("must be addressed using the specified endpoint")) {
                throw new BizException("图片上传 OSS 失败：请确认 OSS_ENDPOINT 与 Bucket 所在地域一致");
            }
            throw new BizException("图片上传 OSS 失败：" + (e.getErrorMessage() == null ? e.getErrorCode() : e.getErrorMessage()));
        } catch (Exception e) {
            log.warn("OSS upload error: {}", e.toString());
            throw new BizException("图片上传 OSS 失败");
        }
    }

    private String publicUrl(String key) {
        AppProperties.Oss oss = appProperties.getOss();
        String base = oss.getPublicBaseUrl();
        if (notBlank(base)) {
            return trimSlash(base.trim()) + "/" + key;
        }
        String endpoint = normalizeEndpoint(oss.getEndpoint()).replace("https://", "").replace("http://", "");
        return "https://" + oss.getBucket().trim() + "." + endpoint + "/" + key;
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
        // 误填成 bucket.oss-cn-xxx.aliyuncs.com 时剥掉 bucket 前缀
        if (e.contains(".oss-") && e.contains(".aliyuncs.com")) {
            int idx = e.indexOf(".oss-");
            if (idx > 0) {
                e = e.substring(idx + 1);
            }
        }
        if (!e.startsWith("http://") && !e.startsWith("https://")) {
            e = "https://" + e;
        }
        if (e.endsWith("/")) {
            e = e.substring(0, e.length() - 1);
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
