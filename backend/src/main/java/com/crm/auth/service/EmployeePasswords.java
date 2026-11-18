package com.crm.auth.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;
import java.security.GeneralSecurityException;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.HexFormat;

@Component
public class EmployeePasswords {
    private static final HexFormat HEX = HexFormat.of();
    private final SecureRandom random = new SecureRandom();
    private final String initialPassword;

    public EmployeePasswords(@Value("${CRM_INITIAL_EMPLOYEE_PASSWORD:123456}") String initialPassword) {
        this.initialPassword = initialPassword;
    }

    public String initialHash() {
        return hash(initialPassword);
    }

    public String hash(String password) {
        byte[] salt = new byte[16];
        random.nextBytes(salt);
        return HEX.formatHex(salt) + ":" + HEX.formatHex(derive(password, salt));
    }

    public boolean matches(String password, String stored) {
        String[] parts = stored.split(":");
        return MessageDigest.isEqual(HEX.parseHex(parts[1]), derive(password, HEX.parseHex(parts[0])));
    }

    private byte[] derive(String password, byte[] salt) {
        PBEKeySpec spec = new PBEKeySpec(password.toCharArray(), salt, 600_000, 256);
        try {
            return SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).getEncoded();
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException(e);
        } finally {
            spec.clearPassword();
        }
    }
}

