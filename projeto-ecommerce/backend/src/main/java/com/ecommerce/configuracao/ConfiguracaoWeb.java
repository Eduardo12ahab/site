package com.ecommerce.configuracao;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class ConfiguracaoWeb implements WebMvcConfigurer {

    private final InterceptorSessao interceptorSessao;

    public ConfiguracaoWeb(InterceptorSessao interceptorSessao) {
        this.interceptorSessao = interceptorSessao;
    }

    @Override
    public void addInterceptors(InterceptorRegistry registo) {
        registo.addInterceptor(interceptorSessao).addPathPatterns("/api/**");
    }
}
