package com.crm.profile.service;

import com.crm.auth.mapper.AuthMapper;
import com.crm.auth.model.LoginAccount;
import com.crm.auth.service.EmployeePasswords;
import com.crm.profile.mapper.ProfileMapper;
import com.crm.profile.model.LoginRecord;
import com.crm.profile.model.Profile;
import jakarta.servlet.http.HttpSession;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.util.Base64;
import java.util.List;

@Service
public class ProfileService {
    private static final String JPEG_PREFIX = "data:image/jpeg;base64,";
    private final ProfileMapper mapper;
    private final AuthMapper accounts;
    private final EmployeePasswords passwords;

    public ProfileService(ProfileMapper mapper, AuthMapper accounts, EmployeePasswords passwords) {
        this.mapper = mapper;
        this.accounts = accounts;
        this.passwords = passwords;
    }

    public Profile get(HttpSession session) {
        return mapper.find(account(session).id(), loginId(session));
    }

    public void update(HttpSession session, String name, String phone, String email) {
        if (name == null || name.isBlank() || name.strip().length() > 100
                || (phone != null && phone.length() > 32) || (email != null && email.length() > 254)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid profile details");
        }
        mapper.update(account(session).id(), name.strip(), phone, email);
    }

    public String uploadAvatar(HttpSession session, String avatar) {
        long id = account(session).id();
        if (avatar == null || avatar.length() > 350_000 || !avatar.startsWith(JPEG_PREFIX)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Upload a JPEG avatar");
        }
        try {
            byte[] image = Base64.getDecoder().decode(avatar.substring(JPEG_PREFIX.length()));
            if (image.length < 4 || image[0] != (byte) 0xff || image[1] != (byte) 0xd8) {
                throw new IllegalArgumentException();
            }
        } catch (IllegalArgumentException e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid JPEG avatar");
        }
        mapper.updateAvatar(id, avatar);
        return avatar;
    }

    public void changePassword(HttpSession session, String oldPassword, String newPassword) {
        LoginAccount account = account(session);
        if (oldPassword == null || !passwords.matches(oldPassword, account.passwordHash())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Incorrect current password");
        }
        if (newPassword == null || newPassword.length() < 8 || newPassword.length() > 128
                || newPassword.isBlank() || newPassword.equals(oldPassword)) {
            throw new ResponseStatusException(HttpStatus.UNPROCESSABLE_ENTITY, "Invalid new password");
        }
        if (mapper.updatePassword(account.id(), account.passwordHash(), passwords.hash(newPassword)) == 0) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Password changed. Try again.");
        }
    }

    public List<LoginRecord> logins(HttpSession session) {
        return mapper.logins(account(session).id(), loginId(session));
    }

    private LoginAccount account(HttpSession session) {
        Long id = session == null ? null : (Long) session.getAttribute("employeeId");
        LoginAccount account = id == null ? null : accounts.findById(id);
        if (account == null) throw new ResponseStatusException(HttpStatus.UNAUTHORIZED);
        return account;
    }

    private String loginId(HttpSession session) {
        Object loginId = session.getAttribute("loginRecordId");
        return loginId == null ? "" : loginId.toString();
    }
}

