public with sharing class CampaignHierarchyController {

    public class ActivityDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String type; // Task | Event
        @AuraEnabled public String subject;
        @AuraEnabled public String status;
        @AuraEnabled public String priority;
        @AuraEnabled public Date activityDate;
        @AuraEnabled public Datetime eventStartDateTime;
        @AuraEnabled public Datetime completedDateTime;
        @AuraEnabled public Id whoId;
        @AuraEnabled public Id whatId;
        @AuraEnabled public String ownerName;

        public ActivityDTO() {}

        public ActivityDTO(Task t) {
            this.id = t.Id;
            this.type = 'Task';
            this.subject = t.Subject;
            this.status = t.Status;
            this.priority = t.Priority;
            this.activityDate = t.ActivityDate;
            this.eventStartDateTime = null;
            this.completedDateTime = t.CompletedDateTime;
            this.whoId = t.WhoId;
            this.whatId = t.WhatId;
            this.ownerName = t.Owner != null ? t.Owner.Name : null;
        }

        public ActivityDTO(Event e) {
            this.id = e.Id;
            this.type = 'Event';
            this.subject = e.Subject;
            this.status = null;
            this.priority = null;
            this.activityDate = e.ActivityDate;
            this.eventStartDateTime = e.StartDateTime;
            this.completedDateTime = null;
            this.whoId = e.WhoId;
            this.whatId = e.WhatId;
            this.ownerName = e.Owner != null ? e.Owner.Name : null;
        }
    }


    public class MemberDTO {
        @AuraEnabled public Id campaignMemberId;
        @AuraEnabled public String memberStatus;

        @AuraEnabled public Id personId;
        @AuraEnabled public String personType;
        @AuraEnabled public String name;
        @AuraEnabled public String companyOrAccount;
        @AuraEnabled public String email;
        @AuraEnabled public String leadOrContactStatus;

        @AuraEnabled public ActivityDTO nextActivity;
        @AuraEnabled public ActivityDTO lastCompletedActivity;
    }

    public class OpportunityDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String stageName;
        @AuraEnabled public Date closeDate;
        @AuraEnabled public String accountName;
        @AuraEnabled public String ownerName;

        public OpportunityDTO(Opportunity o) {
            this.id = o.Id;
            this.name = o.Name;
            this.amount = o.Amount;
            this.stageName = o.StageName;
            this.closeDate = o.CloseDate;
            this.accountName = o.Account != null ? o.Account.Name : null;
            this.ownerName = o.Owner != null ? o.Owner.Name : null;
        }
    }

    public class CampaignDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String type;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public List<MemberDTO> members = new List<MemberDTO>();
        @AuraEnabled public List<OpportunityDTO> opportunities = new List<OpportunityDTO>();
    }

    public class CampaignListItemDTO {
        @AuraEnabled public Id Id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public Integer opportunityCount;
    }

    @AuraEnabled(cacheable=true)
    public static CampaignDTO getCampaignHierarchyById(Id campaignId) {
        if (campaignId == null) {
            throw new AuraHandledException('campaignId es obligatorio');
        }

        Campaign campaign = [
            SELECT Id, Name, Status, Type, StartDate, EndDate, IsActive
            FROM Campaign
            WHERE Id = :campaignId
            LIMIT 1
        ];

        CampaignDTO result = new CampaignDTO();
        result.id = campaign.Id;
        result.name = campaign.Name;
        result.status = campaign.Status;
        result.type = campaign.Type;
        result.startDate = campaign.StartDate;
        result.endDate = campaign.EndDate;
        result.isActive = campaign.IsActive;

        List<CampaignMember> campaignMembers = [
            SELECT Id, CampaignId, Status, LeadId, ContactId
            FROM CampaignMember
            WHERE CampaignId = :campaignId
        ];

        Set<Id> leadIds = new Set<Id>();
        Set<Id> contactIds = new Set<Id>();

        for (CampaignMember cm : campaignMembers) {
            if (cm.LeadId != null) leadIds.add(cm.LeadId);
            if (cm.ContactId != null) contactIds.add(cm.ContactId);
        }

        Map<Id, Lead> leadMap = new Map<Id, Lead>();
        if (!leadIds.isEmpty()) {
            leadMap = new Map<Id, Lead>([
                SELECT Id, Name, Company, Email, Status
                FROM Lead
                WHERE Id IN :leadIds
            ]);
        }

        Map<Id, Contact> contactMap = new Map<Id, Contact>();
        if (!contactIds.isEmpty()) {
            contactMap = new Map<Id, Contact>([
                SELECT Id, Name, Email, Account.Name
                FROM Contact
                WHERE Id IN :contactIds
            ]);
        }

        Map<Id, MemberDTO> personIdToMember = new Map<Id, MemberDTO>();

        for (CampaignMember cm : campaignMembers) {
            MemberDTO member = new MemberDTO();
            member.campaignMemberId = cm.Id;
            member.memberStatus = cm.Status;

            if (cm.LeadId != null && leadMap.containsKey(cm.LeadId)) {
                Lead l = leadMap.get(cm.LeadId);
                member.personId = l.Id;
                member.personType = 'Lead';
                member.name = l.Name;
                member.companyOrAccount = l.Company;
                member.email = l.Email;
                member.leadOrContactStatus = l.Status;
                personIdToMember.put(l.Id, member);
            } else if (cm.ContactId != null && contactMap.containsKey(cm.ContactId)) {
                Contact c = contactMap.get(cm.ContactId);
                member.personId = c.Id;
                member.personType = 'Contact';
                member.name = c.Name;
                member.companyOrAccount = c.Account != null ? c.Account.Name : null;
                member.email = c.Email;
                member.leadOrContactStatus = null;
                personIdToMember.put(c.Id, member);
            }

            result.members.add(member);
        }

        if (!personIdToMember.isEmpty()) {
            Set<Id> personIds = personIdToMember.keySet();
            Date today = Date.today();

            List<Task> openTasks = [
                SELECT Id, Subject, Status, Priority, ActivityDate, CompletedDateTime, WhoId, WhatId, Owner.Name
                FROM Task
                WHERE WhoId IN :personIds
                AND ActivityDate >= :today
                AND ActivityDate != NULL
                AND Status = 'Open'
                ORDER BY WhoId, ActivityDate ASC, CreatedDate ASC
            ];

            Map<Id, Task> nextOpenTaskByWho = new Map<Id, Task>();
            for (Task t : openTasks) {
                if (t.WhoId != null && !nextOpenTaskByWho.containsKey(t.WhoId)) {
                    nextOpenTaskByWho.put(t.WhoId, t);
                }
            }

            List<Task> completedTasks = [
                SELECT Id, Subject, Status, Priority, ActivityDate, CompletedDateTime, WhoId, WhatId, Owner.Name
                FROM Task
                WHERE WhoId IN :personIds
                AND Status = 'Completed'
                AND CompletedDateTime != NULL
                ORDER BY WhoId, CompletedDateTime DESC
            ];

            Map<Id, Task> lastCompletedTaskByWho = new Map<Id, Task>();
            for (Task t : completedTasks) {
                if (t.WhoId != null && !lastCompletedTaskByWho.containsKey(t.WhoId)) {
                    lastCompletedTaskByWho.put(t.WhoId, t);
                }
            }

            List<Event> futureEvents = [
                SELECT Id, Subject, ActivityDate, StartDateTime, WhoId, WhatId, Owner.Name
                FROM Event
                WHERE WhoId IN :personIds
                AND ActivityDate >= :today
                AND ActivityDate != NULL
                ORDER BY WhoId, ActivityDate ASC, StartDateTime ASC, CreatedDate ASC
            ];

            Map<Id, Event> nextEventByWho = new Map<Id, Event>();
            for (Event e : futureEvents) {
                if (e.WhoId != null && !nextEventByWho.containsKey(e.WhoId)) {
                    nextEventByWho.put(e.WhoId, e);
                }
            }

            List<Event> pastEvents = [
                SELECT Id, Subject, ActivityDate, StartDateTime, WhoId, WhatId, Owner.Name
                FROM Event
                WHERE WhoId IN :personIds
                AND ActivityDate < :today
                AND ActivityDate != NULL
                ORDER BY WhoId, ActivityDate DESC, StartDateTime DESC, CreatedDate DESC
            ];

            Map<Id, Event> lastEventByWho = new Map<Id, Event>();
            for (Event e : pastEvents) {
                if (e.WhoId != null && !lastEventByWho.containsKey(e.WhoId)) {
                    lastEventByWho.put(e.WhoId, e);
                }
            }

            for (Id personId : personIds) {
                MemberDTO member = personIdToMember.get(personId);

                Task nextTask = nextOpenTaskByWho.get(personId);
                Event nextEvent = nextEventByWho.get(personId);
                Task lastCompletedTask = lastCompletedTaskByWho.get(personId);
                Event lastEvent = lastEventByWho.get(personId);

                if (nextTask != null && nextEvent != null) {
                    Datetime taskDateTime = Datetime.newInstance(
                        nextTask.ActivityDate,
                        Time.newInstance(0, 0, 0, 0)
                    );

                    Datetime eventDateTime = nextEvent.StartDateTime != null
                        ? nextEvent.StartDateTime
                        : Datetime.newInstance(
                            nextEvent.ActivityDate,
                            Time.newInstance(0, 0, 0, 0)
                        );

                    if (taskDateTime <= eventDateTime) {
                        member.nextActivity = new ActivityDTO(nextTask);
                    } else {
                        member.nextActivity = new ActivityDTO(nextEvent);
                    }
                } else if (nextTask != null) {
                    member.nextActivity = new ActivityDTO(nextTask);
                } else if (nextEvent != null) {
                    member.nextActivity = new ActivityDTO(nextEvent);
                }
                if (lastEvent != null && lastCompletedTask != null) {
                    Datetime taskDateTime = lastCompletedTask.CompletedDateTime != null
                        ? lastCompletedTask.CompletedDateTime
                        : Datetime.newInstance(
                            lastCompletedTask.ActivityDate,
                            Time.newInstance(0, 0, 0, 0)
                        );

                    Datetime eventDateTime = lastEvent.StartDateTime != null
                        ? lastEvent.StartDateTime
                        : Datetime.newInstance(
                            lastEvent.ActivityDate,
                            Time.newInstance(0, 0, 0, 0)
                        );

                    if (taskDateTime >= eventDateTime) {
                        member.lastCompletedActivity = new ActivityDTO(lastCompletedTask);
                    } else {
                        member.lastCompletedActivity = new ActivityDTO(lastEvent);
                    }
                } else if (lastEvent != null) {
                    member.lastCompletedActivity = new ActivityDTO(lastEvent);
                } else if (lastCompletedTask != null) {
                    member.lastCompletedActivity = new ActivityDTO(lastCompletedTask);
                } else {
                    member.lastCompletedActivity = null;    
                }
            }
        }

        List<Opportunity> opportunities = [
            SELECT Id, Name, Amount, StageName, CloseDate, CampaignId, Account.Name, Owner.Name
            FROM Opportunity
            WHERE CampaignId = :campaignId
            ORDER BY CloseDate DESC, CreatedDate DESC
        ];

        for (Opportunity o : opportunities) {
            result.opportunities.add(new OpportunityDTO(o));
        }

        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<CampaignListItemDTO> getAllActiveCampaigns() {
        List<Campaign> campaigns = [
            SELECT Id, Name, Status
            FROM Campaign
            WHERE IsActive = true
        ];

        List<CampaignListItemDTO> result = new List<CampaignListItemDTO>();
        if (campaigns.isEmpty()) {
            return result;
        }

        Set<Id> campaignIds = new Set<Id>();
        for (Campaign c : campaigns) {
            campaignIds.add(c.Id);
        }

        Map<Id, Integer> oppCountByCampaign = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT CampaignId campaignId, COUNT(Id) oppCount
            FROM Opportunity
            WHERE CampaignId IN :campaignIds
            GROUP BY CampaignId
        ]) {
            oppCountByCampaign.put(
                (Id) ar.get('campaignId'),
                Integer.valueOf(String.valueOf(ar.get('oppCount')))
            );
        }

        for (Campaign c : campaigns) {
            CampaignListItemDTO dto = new CampaignListItemDTO();
            dto.Id = c.Id;
            dto.name = c.Name;
            dto.status = c.Status;
            dto.opportunityCount = oppCountByCampaign.containsKey(c.Id)
                ? oppCountByCampaign.get(c.Id)
                : 0;
            result.add(dto);
        }

        result.sort(new CampaignListItemComparator());
        return result;
    }

    public class CampaignListItemComparator implements System.Comparator<CampaignListItemDTO> {
        public Integer compare(CampaignListItemDTO a, CampaignListItemDTO b) {
            Integer countA = a.opportunityCount != null ? a.opportunityCount : 0;
            Integer countB = b.opportunityCount != null ? b.opportunityCount : 0;

            if (countA == countB) {
                String nameA = a.name != null ? a.name.toLowerCase() : '';
                String nameB = b.name != null ? b.name.toLowerCase() : '';

                if (nameA == nameB) return 0;
                return nameA < nameB ? -1 : 1;
            }

            return countB - countA;
        }
    }
}