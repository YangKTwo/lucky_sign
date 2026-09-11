package com.luckysign.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.Resource;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.ViewControllerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;
import org.springframework.web.servlet.resource.PathResourceResolver;

import java.io.IOException;
import java.nio.file.Path;

@Configuration
public class WebMvcConfig implements WebMvcConfigurer {
    private final AppProperties appProperties;

    public WebMvcConfig(AppProperties appProperties) {
        this.appProperties = appProperties;
    }

    @Override
    public void addViewControllers(ViewControllerRegistry registry) {
        // /app → /app/ ，方便分享短链接
        registry.addRedirectViewController("/app", "/app/");
    }

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        registry.addResourceHandler("/uploads/**")
                .addResourceLocations(toDirLocation(appProperties.getUpload().getDir()));
        registry.addResourceHandler("/downloads/**")
                .addResourceLocations(toDirLocation(appProperties.getDownload().getDir()));

        String webLocation = toDirLocation(appProperties.getWeb().getDir());
        registry.addResourceHandler("/app/", "/app/**")
                .addResourceLocations(webLocation)
                .resourceChain(true)
                .addResolver(new PathResourceResolver() {
                    @Override
                    protected Resource getResource(String resourcePath, Resource location) throws IOException {
                        Resource requested = super.getResource(resourcePath, location);
                        if (requested != null && requested.exists() && requested.isReadable()) {
                            return requested;
                        }
                        // SPA / 刷新兜底：回 index.html
                        return super.getResource("index.html", location);
                    }
                });
    }

    private static String toDirLocation(String dir) {
        String location = Path.of(dir).toAbsolutePath().normalize().toUri().toString();
        return location.endsWith("/") ? location : location + "/";
    }
}
