#!/bin/bash

read -p "názov: " folderName || exit 1

if [[ "${folderName}" =~ [^a-zA-Z\-] ]]; then
   echo 'Nesprávny formát'
   exit 1
fi

resourceName=''
if [[ $folderName == *"-"* ]]; then
  index=0
  IFS='-' read -ra ADDR <<< "$folderName"
  for i in "${ADDR[@]}"; do
    split=$i
    if [[ $index -gt 0 ]]
    then
      split="$(tr '[:lower:]' '[:upper:]' <<< ${split:0:1})${split:1}"
    fi

    resourceName+=$split
    index=$(expr $index + 1)
  done
else
  resourceName=$folderName
fi

resourceNameCapitalized="$(tr '[:lower:]' '[:upper:]' <<< ${resourceName:0:1})${resourceName:1}"

serviceTemplate="
  import { Injectable } from '@nestjs/common'
  import { ResourceRepository } from '~/database/resource.repository'

  @Injectable()
  export class ${resourceNameCapitalized}Service extends ResourceRepository {
    get resourceName(): string {
      return '${folderName}'
    }
  }
"

moduleTemplate="
  import { Module } from '@nestjs/common'
  import { ${resourceNameCapitalized}Controller } from '~/${folderName}/${folderName}.controller'
  import { ${resourceNameCapitalized}Service } from '~/${folderName}/${folderName}.service'
  import { ${resourceNameCapitalized}DataSeed } from '~/${folderName}/data/${folderName}.data.seed'

  @Module({
    controllers: [${resourceNameCapitalized}Controller],
    providers: [${resourceNameCapitalized}Service, ${resourceNameCapitalized}DataSeed],
    exports: [${resourceNameCapitalized}DataSeed],
    imports: [],
  })
  export class ${resourceNameCapitalized}Module {}
"

controllerTemplate="
  import { Controller, Get } from '@nestjs/common'
  import { ${resourceNameCapitalized}Service } from '~/${folderName}/${folderName}.service'

  @Controller('${folderName}')
  export class ${resourceNameCapitalized}Controller {
    constructor(private readonly ${resourceName}Service: ${resourceNameCapitalized}Service) {}

    @Get('/')
    async get() {
      return this.${resourceName}Service.resource.value()
    }
  }
"

dataTemplate="
  import { Injectable } from '@nestjs/common'
  import { DataSeed } from '~/database/data.seed'

  @Injectable()
  export class ${resourceNameCapitalized}DataSeed implements DataSeed {
    seed(): any {
      return []
    }

    name(): string {
      return '${folderName}'
    }
  }
"

appModuleLineNum="$(grep -n "imports:" ./src/app.module.ts | head -n 1 | cut -d: -f1)"
appModuleContent=$({ head -n +$appModuleLineNum ./src/app.module.ts; echo "${resourceNameCapitalized}Module,"; tail -n +$(expr $appModuleLineNum + 1) ./src/app.module.ts; })
printf '%s' "$appModuleContent" > ./src/app.module.ts
appModuleContent=$({ head -n +3 ./src/app.module.ts; echo "import { ${resourceNameCapitalized}Module } from '~/${folderName}/${folderName}.module'"; tail -n +4 ./src/app.module.ts; })
printf '%s' "$appModuleContent" > ./src/app.module.ts

databaseLineNum="$(grep -n "inject:" ./src/database/database.service.ts | head -n 1 | cut -d: -f1)"
databaseContent=$({ head -n +$databaseLineNum ./src/database/database.service.ts; echo "${resourceNameCapitalized}DataSeed,"; tail -n +$(expr $databaseLineNum + 1) ./src/database/database.service.ts; })
printf '%s' "$databaseContent" > ./src/database/database.service.ts 
databaseLineNum="$(grep -n "useFactory:" ./src/database/database.service.ts | head -n 1 | cut -d: -f1)"
databaseContent=$({ head -n +$databaseLineNum ./src/database/database.service.ts; echo "${resourceName}DataSeed: ${resourceNameCapitalized}DataSeed,"; tail -n +$(expr $databaseLineNum + 1) ./src/database/database.service.ts; })
printf '%s' "$databaseContent" > ./src/database/database.service.ts 
databaseLineNum="$(grep -n "db.defaults({" ./src/database/database.service.ts | head -n 1 | cut -d: -f1)"
databaseContent=$({ head -n +$databaseLineNum ./src/database/database.service.ts; echo "[${resourceName}DataSeed.name()]: ${resourceName}DataSeed.seed(),"; tail -n +$(expr $databaseLineNum + 1) ./src/database/database.service.ts; })
printf '%s' "$databaseContent" > ./src/database/database.service.ts 
databaseContent=$({ head -n +3 ./src/database/database.service.ts; echo "import { ${resourceNameCapitalized}DataSeed } from '~/${folderName}/data/${folderName}.data.seed'"; tail -n +4 ./src/database/database.service.ts; })
printf '%s' "$databaseContent" > ./src/database/database.service.ts 

eval "mkdir ./src/${folderName}"
printf '%s' "${serviceTemplate}" > ./src/${folderName}/${folderName}.service.ts
printf '%s' "${controllerTemplate}" > ./src/${folderName}/${folderName}.controller.ts
printf '%s' "${moduleTemplate}" > ./src/${folderName}/${folderName}.module.ts

eval "mkdir ./src/${folderName}/data"
printf '%s' "${dataTemplate}" > ./src/${folderName}/data/${folderName}.data.seed.ts

eval "npm run lint -- --fix"

