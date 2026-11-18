package com.crm.auth.service;

import com.crm.auth.mapper.AuthMapper;
import com.crm.auth.model.LoginAccount;
import com.crm.auth.model.SessionUser;
import org.springframework.boot.CommandLineRunner;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

@Service
public class AuthService implements CommandLineRunner {
    private final AuthMapper mapper;
    private final EmployeePasswords passwords;

    public AuthService(AuthMapper mapper, EmployeePasswords passwords) {
        this.mapper = mapper;
        this.passwords = passwords;
    }

    @Override
    public void run(String... args) {
        for (long id : mapper.employeesWithoutPassword()) {
            mapper.initializePassword(id, passwords.initialHash());
        }
    }

    public SessionUser login(String username, String password) {
        LoginAccount account = username == null ? null : mapper.findByUsername(username.trim());
        if (account == null || password == null || account.passwordHash() == null
                || !passwords.matches(password, account.passwordHash())) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED);
        }
        return user(account);
    }

    public SessionUser current(long id) {
        LoginAccount account = mapper.findById(id);
        if (account == null) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED);
        }
        return user(account);
    }

    private SessionUser user(LoginAccount account) {
        var roles = mapper.roleNames(account.id());
        return new SessionUser(account.id(), account.account(), account.name(), account.dept(),
                roles.isEmpty() ? "未分配" : String.join("、", roles), mapper.permissions(account.id()));
    }
}
