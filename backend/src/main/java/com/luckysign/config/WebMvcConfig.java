package com.luckysign.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.nio.file.Path;

@Configuration
public class WebMvcConfig implements WebMvcConfigurer {
    private final AppProperties appProperties;

    public WebMvcConfig(AppProperties appProperties) {
        this.appProperties = appProperties;
    }

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        registry.addResourceHandler("/uploads/**")
                .addResourceLocations(toDirLocation(appProperties.getUpload().getDir()));
        registry.addResourceHandler("/downloads/**")
                .addResourceLocations(toDirLocation(appProperties.getDownload().getDir()));
    }

    private static String toDirLocation(String dir) {
        String location = Path.of(dir).toAbsolutePath().normalize().toUri().toString();
        return location.endsWith("/") ? location : location + "/";
    }
}
