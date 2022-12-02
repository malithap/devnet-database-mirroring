param location string = resourceGroup().location
param appHostingPlan string = 'B2'
param environment string = 'sod'
@secure()
param sqlAdministratorPassword string
param sqlAdministratorSid string

var sqlServerName = 'sql-mirroring-${environment}'
var sqlAdministratorLogin = 'MirroringSqlAdmin'
var sqlServerFilewallRulesArray = [
  {
    name: 'AllowAllWindowsAzureIps'
    ipAddress: '0.0.0.0'
  }
  {
    name: 'AllowSuperOfficeOld'
    ipAddress: '217.144.239.130'
  }
  {
    name: 'AllowSuperOffice'
    ipAddress: '195.1.42.202'
  }
  {
    name: 'AllowSuperOfficeWifi'
    ipAddress: '91.123.49.64'
  }
]

var baseDatabaseConnectionString = 'Server=tcp:${sqlServerName}${az.environment().suffixes.sqlServerHostname},1433;User ID=${sqlAdministratorLogin};Password=${sqlAdministratorPassword}'
var webAppHostingPlanName = 'plan-mirroring-${environment}'
var webAppName = 'app-mirroring-${environment}'

// SQL server
resource sqlServer 'Microsoft.Sql/servers@2021-11-01' = {
  name: sqlServerName
  location: location
  tags: {
    displayName: 'SQL Server'
  }
  properties: {
    administratorLogin: sqlAdministratorLogin
    administratorLoginPassword: sqlAdministratorPassword
    version: '12.0'
    publicNetworkAccess: 'Enabled'
  }
}

resource sqlServerAdmin 'Microsoft.Sql/servers/administrators@2021-11-01' = {
  parent: sqlServer
  name: 'ActiveDirectory'
  properties: {
    administratorType: 'ActiveDirectory'
    login: 'aad_${sqlAdministratorLogin}'
    sid: sqlAdministratorSid
  }
}

resource sqlServerFilewallRules 'Microsoft.Sql/servers/firewallRules@2021-11-01' = [for sqlServerFilewallRule in sqlServerFilewallRulesArray: {
  parent: sqlServer
  name: sqlServerFilewallRule.name
  properties: {
    startIpAddress: sqlServerFilewallRule.ipAddress
    endIpAddress: sqlServerFilewallRule.ipAddress
  }
}]

resource webAppHostingPlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: webAppHostingPlanName
  location: location
  tags: {
    displayName: 'Web App Hosting Plan'
  }
  sku: {
    name: appHostingPlan
  }
}

resource webApp 'Microsoft.Web/sites@2022-03-01' = {
  name: webAppName
  location: location
  tags: {
    'hidden-related:${resourceGroup().id}/providers/Microsoft.Web/serverfarms/${webAppHostingPlanName}': 'Resource'
    displayName: '${webAppName} Web App'
  }
  properties: {
    serverFarmId: webAppHostingPlan.id
    httpsOnly: true
  }
  identity: {
    type: 'SystemAssigned'
  }
}

output webAppName string = webAppName
output baseDatabaseConnectionString string = baseDatabaseConnectionString

