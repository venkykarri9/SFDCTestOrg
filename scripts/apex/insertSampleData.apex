// Territories
List<Sales_Territory__c> territories = new List<Sales_Territory__c>{
    new Sales_Territory__c(Name='North America East', Region__c='East', Annual_Target__c=5000000, Active__c=true, Country_Code__c='US'),
    new Sales_Territory__c(Name='North America West', Region__c='West', Annual_Target__c=6000000, Active__c=true, Country_Code__c='US'),
    new Sales_Territory__c(Name='EMEA', Region__c='International', Annual_Target__c=4000000, Active__c=true, Country_Code__c='GB'),
    new Sales_Territory__c(Name='APAC', Region__c='International', Annual_Target__c=3500000, Active__c=true, Country_Code__c='SG'),
    new Sales_Territory__c(Name='Central', Region__c='Central', Annual_Target__c=2500000, Active__c=true, Country_Code__c='US')
};
insert territories;

// Accounts
List<Account> accounts = new List<Account>{
    new Account(Name='Acme Corporation', Industry='Technology', AnnualRevenue=50000000, BillingState='CA'),
    new Account(Name='Global Industries', Industry='Manufacturing', AnnualRevenue=120000000, BillingState='NY'),
    new Account(Name='Tech Ventures Ltd', Industry='Technology', AnnualRevenue=25000000, BillingState='TX'),
    new Account(Name='MegaCorp Holdings', Industry='Finance', AnnualRevenue=500000000, BillingState='IL'),
    new Account(Name='StartupXYZ', Industry='Technology', AnnualRevenue=5000000, BillingState='WA'),
    new Account(Name='Enterprise Solutions', Industry='Consulting', AnnualRevenue=80000000, BillingState='MA'),
    new Account(Name='Pacific Retail Group', Industry='Retail', AnnualRevenue=200000000, BillingState='CA'),
    new Account(Name='Healthcare Partners', Industry='Healthcare', AnnualRevenue=150000000, BillingState='FL')
};
insert accounts;

// Contacts
List<Contact> contacts = new List<Contact>{
    new Contact(FirstName='John', LastName='Smith', Email='john.smith@acme.com', AccountId=accounts[0].Id, Title='VP Sales'),
    new Contact(FirstName='Sarah', LastName='Johnson', Email='sarah.j@global.com', AccountId=accounts[1].Id, Title='CTO'),
    new Contact(FirstName='Mike', LastName='Davis', Email='mike.d@techventures.com', AccountId=accounts[2].Id, Title='CEO'),
    new Contact(FirstName='Lisa', LastName='Wong', Email='lisa.w@megacorp.com', AccountId=accounts[3].Id, Title='CFO'),
    new Contact(FirstName='Tom', LastName='Brown', Email='tom.b@startupxyz.com', AccountId=accounts[4].Id, Title='Founder'),
    new Contact(FirstName='Emma', LastName='Wilson', Email='emma.w@enterprise.com', AccountId=accounts[5].Id, Title='Director')
};
insert contacts;

// Deals
List<Deal__c> deals = new List<Deal__c>{
    new Deal__c(Account__c=accounts[0].Id, Primary_Contact__c=contacts[0].Id, Deal_Stage__c='Proposal', Deal_Value__c=250000, Win_Probability__c=50, Close_Date__c=Date.today().addDays(30), Deal_Source__c='Inbound', Is_Strategic__c=true, Territory__c=territories[1].Id),
    new Deal__c(Account__c=accounts[1].Id, Primary_Contact__c=contacts[1].Id, Deal_Stage__c='Negotiation', Deal_Value__c=500000, Win_Probability__c=75, Close_Date__c=Date.today().addDays(15), Deal_Source__c='Outbound', Is_Strategic__c=true, Territory__c=territories[0].Id),
    new Deal__c(Account__c=accounts[2].Id, Primary_Contact__c=contacts[2].Id, Deal_Stage__c='Qualification', Deal_Value__c=50000, Win_Probability__c=25, Close_Date__c=Date.today().addDays(45), Deal_Source__c='Referral', Territory__c=territories[1].Id),
    new Deal__c(Account__c=accounts[3].Id, Primary_Contact__c=contacts[3].Id, Deal_Stage__c='Closed Won', Deal_Value__c=1000000, Win_Probability__c=100, Close_Date__c=Date.today().addDays(-5), Deal_Source__c='Partner', Is_Strategic__c=true, Territory__c=territories[0].Id),
    new Deal__c(Account__c=accounts[4].Id, Primary_Contact__c=contacts[4].Id, Deal_Stage__c='Prospecting', Deal_Value__c=25000, Win_Probability__c=10, Close_Date__c=Date.today().addDays(60), Deal_Source__c='Inbound', Territory__c=territories[1].Id),
    new Deal__c(Account__c=accounts[5].Id, Primary_Contact__c=contacts[5].Id, Deal_Stage__c='Proposal', Deal_Value__c=180000, Win_Probability__c=50, Close_Date__c=Date.today().addDays(20), Deal_Source__c='Event', Territory__c=territories[0].Id),
    new Deal__c(Account__c=accounts[6].Id, Deal_Stage__c='Closed Lost', Deal_Value__c=300000, Win_Probability__c=0, Close_Date__c=Date.today().addDays(-10), Deal_Source__c='Outbound', Next_Step__c='Lost to competitor on pricing', Territory__c=territories[1].Id),
    new Deal__c(Account__c=accounts[7].Id, Deal_Stage__c='Negotiation', Deal_Value__c=750000, Win_Probability__c=75, Close_Date__c=Date.today().addDays(10), Deal_Source__c='Partner', Is_Strategic__c=true, Territory__c=territories[0].Id)
};
insert deals;

// Deal Activities
List<Deal_Activity__c> activities = new List<Deal_Activity__c>{
    new Deal_Activity__c(Deal__c=deals[0].Id, Activity_Type__c='Meeting', Activity_Date__c=DateTime.now().addDays(-5), Outcome__c='Positive', Notes__c='Demo went well. Customer interested in advanced features.', Completed__c=true, Duration_Minutes__c=60),
    new Deal_Activity__c(Deal__c=deals[0].Id, Activity_Type__c='Email', Activity_Date__c=DateTime.now().addDays(-2), Outcome__c='Positive', Notes__c='Sent proposal document. Customer confirmed receipt.', Completed__c=true),
    new Deal_Activity__c(Deal__c=deals[1].Id, Activity_Type__c='Call', Activity_Date__c=DateTime.now().addDays(-3), Outcome__c='Positive', Notes__c='Discussed pricing. They want 10% discount.', Completed__c=true, Duration_Minutes__c=30),
    new Deal_Activity__c(Deal__c=deals[1].Id, Activity_Type__c='Meeting', Activity_Date__c=DateTime.now().addDays(-1), Outcome__c='Neutral', Notes__c='Legal review meeting. Contract sent to their team.', Completed__c=true, Duration_Minutes__c=90),
    new Deal_Activity__c(Deal__c=deals[3].Id, Activity_Type__c='Call', Activity_Date__c=DateTime.now().addDays(-6), Outcome__c='Positive', Notes__c='Final negotiation call. Deal closed!', Completed__c=true, Duration_Minutes__c=45),
    new Deal_Activity__c(Deal__c=deals[7].Id, Activity_Type__c='Demo', Activity_Date__c=DateTime.now().addDays(-4), Outcome__c='Positive', Notes__c='Executive demo to C-suite. Very positive reception.', Completed__c=true, Duration_Minutes__c=120)
};
insert activities;

System.debug('Sample data created successfully!');
System.debug('Territories: ' + territories.size());
System.debug('Accounts: ' + accounts.size());
System.debug('Contacts: ' + contacts.size());
System.debug('Deals: ' + deals.size());
System.debug('Activities: ' + activities.size());
