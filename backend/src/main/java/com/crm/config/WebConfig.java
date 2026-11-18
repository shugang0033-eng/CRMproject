package com.crm.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebConfig implements WebMvcConfigurer {
    private final ApiPermissionInterceptor permissions;

    public WebConfig(ApiPermissionInterceptor permissions) {
        this.permissions = permissions;
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(permissions)
                .addPathPatterns("/api/**")
                .excludePathPatterns("/api/auth/login");
    }
}
