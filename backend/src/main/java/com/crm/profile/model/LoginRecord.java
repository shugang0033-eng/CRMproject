package com.crm.profile.model;

import java.time.LocalDateTime;

public record LoginRecord(String id, String device, String ip, LocalDateTime at, boolean current) {}
