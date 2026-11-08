# Singapore PDPA Compliance Checklist

> **This checklist is manual.** Tick each box when the evidence exists. The
> scanner does not tick boxes. The scanner does not edit this file.

**Last rule update:** 21 June 2026. The checklist follows Singapore PDPA as
revised through the 2026 amendments.

**Toolkit version:** `pdpa-sg` (see `VERSION`).

**Internal targets:** Items marked **Internal target** are organisation policy
choices. They are not quoted from the PDPA. Change them to match your own legal
review.

---

## Summary

| # | Obligation | Status | Scanner support |
|---|---|---|---|
| 1 | Consent | [ ] | no |
| 2 | Purpose Limitation | [ ] | partial |
| 3 | Notification | [ ] | no |
| 4 | Accuracy | [ ] | no |
| 5 | Protection | [ ] | partial |
| 6 | Retention Limitation | [ ] | no |
| 7 | Transfer Limitation (section 26) | [ ] | partial |
| 8 | Access and Correction (DSR) | [ ] | no |
| 9 | Withdrawal of Consent | [ ] | no |
| 10 | Data Breach Notification | [ ] | no |
| 11 | Accountability and DPO | [ ] | partial |

---

## 1. Consent Obligation

> Do not collect, use, or disclose personal data without consent or another
> lawful basis.

- [ ] A consent form exists at each collection point. See
  `resources/policies/CONSENT_FORM.template.md`.
- [ ] Consent records store the timestamp, scope, opt-in text, source, and policy
  version.
- [ ] Withdrawal is as easy as opt-in.
- [ ] The exceptions register is reviewed each year.

---

## 2. Purpose Limitation Obligation

> Collect personal data only for purposes that a reasonable person would
> consider appropriate.

- [ ] Each data field has a documented purpose.
- [ ] The privacy notice states each purpose.
- [ ] New purposes go through a review before collection.
- [ ] Analytics and secondary use have a separate lawful basis.

---

## 3. Notification Obligation

> Tell the individual the purpose, the likely use, and the contact for questions.

- [ ] The privacy notice is available before or at collection.
- [ ] The notice names the organisation and the DPO contact.
- [ ] The notice lists the main data categories and recipients.
- [ ] The notice states the retention approach.

---

## 4. Accuracy Obligation

> Take reasonable steps to ensure that personal data is accurate and complete.

- [ ] Individuals can view and correct their data.
- [ ] Data-quality checks exist at entry and import.
- [ ] Correction requests have an owner and a response path.
- [ ] Downstream systems receive corrections.

---

## 5. Protection Obligation

> Use reasonable security arrangements to protect personal data.

- [ ] Encryption at rest for personal-data fields.
- [ ] Encryption in transit. Use TLS 1.2 or newer.
- [ ] Role-based access control.
- [ ] Access-list review each quarter.
- [ ] Audit logging for data access.
- [ ] Two-factor authentication for data-access roles.
- [ ] Penetration test each year.
- [ ] No hardcoded secrets in tracked files.
- [ ] No raw NRIC or FIN values in code or test data. Use fictional values with
  the `pdpa:ignore` marker.
- [ ] The scanner runs on the project:
  `./bin/pdpa-sg --target . --format json`.

---

## 6. Retention Limitation Obligation

> Stop retaining personal data, or remove the link to the individual, when the
> purpose ends.

- [ ] A retention schedule exists for each data category.
- [ ] An automated purge job runs.
- [ ] **Internal target:** soft-delete data is kept for no more than 90 days,
  unless a legal hold applies.
- [ ] Anonymisation or pseudonymisation is applied before analytics use.
- [ ] Legal holds are documented and reviewed.

---

## 7. Transfer Limitation Obligation (section 26)

> Send personal data overseas only when the receiving organisation is bound by a
> comparable standard.

- [ ] Choose at least one transfer mechanism:
  - [ ] APEC CBPR
  - [ ] APEC PRP
  - [ ] EU SCCs
  - [ ] Binding corporate rules
  - [ ] Contract with comparable safeguards
- [ ] The transfer register lists the country, recipient, and mechanism.
- [ ] The recipient has a breach-notification duty.
- [ ] The recipient has a deletion duty at contract end.

---

## 8. Access and Correction Obligation

> On request, give the individual access to their personal data and information
> about its use. Correct errors on request.

- [ ] A data subject request channel is public.
- [ ] The team logs each request and its deadline.
- [ ] The response package includes the data, the purposes, and the recipients.
- [ ] Correction requests update all linked systems.
- [ ] Refusal reasons are documented and reviewable.

---

## 9. Withdrawal of Consent Obligation

> Withdrawal must work as easily as opt-in. Explain the consequences.

- [ ] A withdrawal endpoint or channel exists.
- [ ] **Internal target:** downstream processing stops, or moves to an
  anonymised aggregate, within 7 days.
- [ ] The individual receives a confirmation.
- [ ] The confirmation explains any records that must be kept by law.

---

## 10. Data Breach Notification Obligation

> Notify the PDPC and affected individuals when a breach is notifiable.

- [ ] A breach response plan exists. See
  `resources/policies/DATA_BREACH_RESPONSE.template.md`.
- [ ] The team assesses a breach without delay.
- [ ] The PDPC notification is submitted within 3 calendar days after assessment.
- [ ] **Internal target:** affected individuals are notified within 30 days.
- [ ] A tabletop drill runs each year.
- [ ] The DPO is reachable during a breach.

---

## 11. Accountability and DPO Designation Obligation

> Designate at least one Data Protection Officer and publish a business contact.

- [ ] A DPO is named with a business email. See
  `resources/policies/DPO_CONTACT.template.md`.
- [ ] The DPO contact is published.
- [ ] The DPO has a direct line to senior management.
- [ ] DPO training is refreshed each year.
- [ ] **Internal target:** PDPA-era logs are kept for 3 years or longer.

---

## AI Governance Addendum

For automated decision-making that uses personal data:

- [ ] Tell users when an automated decision affects them.
- [ ] Keep model outputs explainable to non-experts.
- [ ] Process only the fields that the decision needs.
- [ ] Provide a human review path for adverse decisions.
- [ ] Do not train models on user data without a lawful basis.

---

## Safe NRIC Addendum

> PDPC requires organisations to stop using full or partial NRIC numbers for
> **authentication** by 31 December 2026. **Identification** remains permitted
> under existing collection rules. Collect NRIC only when it is needed and
> lawful.

Primary source:
[PDPC press release, 2 February 2026](https://www.pdpc.gov.sg/media-events/organisations-to-cease-the-use-of-nric-numbers-for-authentication-by-31-december-2026).

- [ ] NRIC is not used as a password, login name, or authentication factor.
- [ ] NRIC authentication flows are removed or replaced by 31 December 2026.
- [ ] NRIC is collected only for identification where the law or a genuine need
  requires it.
- [ ] NRIC values are masked in displays where full values are not needed.
- [ ] NRIC values are encrypted at rest and access is limited.
- [ ] Historical NRIC data used for authentication is retired by 31 December
  2026.
- [ ] The scanner runs before commit:
  `./bin/pdpa-sg --target . --format json`.

---

## Quarterly Review

- [ ] Run `./bin/pdpa-sg --target . --format sarif --out audit.sarif`.
- [ ] Review scanner findings and close or accept each one.
- [ ] Refresh the privacy policy when a data category changes.
- [ ] Verify the DPO contact is live.
- [ ] Review access logs for unusual access.
- [ ] Confirm the rule stamp in `lisp/src/version.lisp` is current.

---

## How to use this checklist

1. Read the obligation.
2. Collect evidence.
3. Tick the box by hand.
4. Record the evidence location in your project notes.
5. Repeat the review each quarter.

The scanner gives evidence for some protection and transfer items. It does not
give legal advice. It does not replace a DPO review.
