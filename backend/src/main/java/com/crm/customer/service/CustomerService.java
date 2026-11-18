package com.crm.customer.service;

import com.crm.customer.mapper.CustomerMapper;
import com.crm.customer.model.CustomerRow;
import com.crm.customer.model.CustomerContact;
import com.crm.lead.mapper.LeadMapper;
import com.crm.lead.service.LeadService;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

@Service
public class CustomerService {
    private final CustomerMapper customers;
    private final LeadMapper leads;
    private final LeadService permissions;

    public CustomerService(CustomerMapper customers, LeadMapper leads, LeadService permissions) {
        this.customers = customers;
        this.leads = leads;
        this.permissions = permissions;
    }

    public Object list(Long employee) {
        permissions.require(employee, "customer.view");
        return customers.list(employee, "customer.view", permissions.has(employee, "payment.view"));
    }

    public List<CustomerContact> contacts(Long employee) {
        permissions.require(employee, "contact.view");
        return customers.contacts(employee, "contact.view");
    }

    @Transactional
    public void convert(Long employee, String id) {
        permissions.require(employee, "lead.convert");
        var lead = leads.lock(id);
        if (lead == null) throw new ResponseStatusException(HttpStatus.NOT_FOUND);
        if (!leads.canAccess(employee, id, "lead.convert")) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN);
        }
        if (lead.ownerId() == null || lead.inPool() || List.of("won", "converted", "invalid").contains(lead.status())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT);
        }
        customers.createFromLead(id, employee);
        customers.copyContact(id);
        leads.markConverted(id);
    }

    @Transactional
    public void transfer(Long employee, List<Long> ids, Long ownerId, String reason) {
        String permission = ownerId == null ? "customer.public.claim" : "lead.transfer";
        permissions.require(employee, permission);
        if (ids == null || ids.isEmpty() || (ownerId != null && leads.activeEmployee(ownerId) == null)
                || (reason != null && reason.length() > 255)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
        }
        for (long id : ids.stream().distinct().sorted().toList()) {
            Long currentOwner = customers.lockOwner(id);
            if (currentOwner == null) throw new ResponseStatusException(HttpStatus.NOT_FOUND);
            if (!customers.canAccess(employee, id, permission)) {
                throw new ResponseStatusException(HttpStatus.FORBIDDEN);
            }
            if (currentOwner.equals(ownerId)) throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
            customers.move(id, ownerId, reason);
            if (ownerId != null) customers.moveTasks(id, ownerId);
            customers.history(id, currentOwner, ownerId, employee, reason);
        }
    }
}




