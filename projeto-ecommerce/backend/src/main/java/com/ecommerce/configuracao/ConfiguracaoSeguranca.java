package com.ecommerce.configuracao;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

@Configuration
public class ConfiguracaoSeguranca {

    /** Apenas o BCrypt (spring-security-crypto), sem o Spring Security completo. */
    @Bean
    public PasswordEncoder codificador() {
        return new BCryptPasswordEncoder();
    }
}
