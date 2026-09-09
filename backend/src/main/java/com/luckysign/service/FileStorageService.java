package com.luckysign.service;

import com.luckysign.common.BizException;
import com.luckysign.config.AppProperties;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Set;
import java.util.UUID;

@Service
public class FileStorageService {
    private static final Set<String> ALLOWED = Set.of("image/jpeg", "image/png", "image/jpg", "image/webp");
    private final Path root;

    public FileStorageService(AppProperties appProperties) throws IOException {
        this.root = Paths.get(appProperties.getUpload().getDir()).toAbsolutePath().normalize();
        Files.createDirectories(this.root);
    }

    public String save(MultipartFile file) {
        if (file.getContentType() == null || !ALLOWED.contains(file.getContentType().toLowerCase())) {
            throw new BizException("仅支持 jpg/png/webp 图片");
        }
        String ext = switch (file.getContentType().toLowerCase()) {
            case "image/png" -> ".png";
            case "image/webp" -> ".webp";
            default -> ".jpg";
        };
        String filename = UUID.randomUUID() + ext;
        try {
            Path target = root.resolve(filename);
            file.transferTo(target);
            return "/uploads/" + filename;
        } catch (IOException e) {
            throw new BizException("图片保存失败");
        }
    }
}
