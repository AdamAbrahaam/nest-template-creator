#!/bin/bash

read -p "resource name: " resourceName || exit 1

serviceTemplate="
  import { Injectable } from '@nestjs/common'
  import { ResourceRepository } from '~/database/resource.repository'

  @Injectable()
  export class ${resourceName}Service extends ResourceRepository {
    get resourceName(): string {
      return '${resourceName}'
    }
  }
"

moduleTemplate="
  import { Module } from '@nestjs/common'
  import { ${resourceName}Controller } from '~/${resourceName}/${resourceName}.controller'
  import { ${resourceName}Service } from '~/${resourceName}/${resourceName}.service'
  import { ${resourceName}DataSeed } from '~/${resourceName}/data/${resourceName}.data.seed'

  @Module({
    controllers: [${resourceName}Controller],
    providers: [${resourceName}Service, ${resourceName}DataSeed],
    exports: [${resourceName}DataSeed],
  })
  export class ${resourceName}Module {}
"

controllerTemplate="
import { Controller, Get } from '@nestjs/common'
import { ${resourceName}Service } from '~/${resourceName}/${resourceName}.service'

@Controller('${resourceName}')
export class ${resourceName}Controller {
  constructor(private readonly ${resourceName}Service: ${resourceName}Service) {}

  @Get('/')
  async get() {
    return this.${resourceName}.resouce.value()
  }
}
"

dataTemplate="
  import { Injectable } from '@nestjs/common'
  import { DataSeed } from '~/database/data.seed'

  @Injectable()
  export class ${resourceName}DataSeed implements DataSeed {
    seed(): any {
      return []
    }

    name(): string {
      return '${resourceName}'
    }
  }
"

appModulelineNum="$(grep -n "imports:" ./src/app.module.ts | head -n 1 | cut -d: -f1)"
appModuleContent=$({ head -n +$appModulelineNum ./src/app.module.ts; echo "${resourceName},"; tail -n +$(expr $appModulelineNum + 1) ./src/app.module.ts; })
printf '%s' "$appModuleContent" > ./src/app.module.ts


eval "mkdir ./src/${resourceName}"
printf '%s' "${serviceTemplate}" > ./src/${resourceName}/${resourceName}.service.ts
printf '%s' "${controllerTemplate}" > ./src/${resourceName}/${resourceName}.controller.ts
printf '%s' "${moduleTemplate}" > ./src/${resourceName}/${resourceName}.module.ts

eval "mkdir ./src/${resourceName}/data"
printf '%s' "${dataTemplate}" > ./src/${resourceName}/data/${resourceName}.data.seed.ts
