package com.crm.lead.model;

import java.util.List;

public record LeadMove(List<String> ids, Long ownerId, String reason, String note) {}
