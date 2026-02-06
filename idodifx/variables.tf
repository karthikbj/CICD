
variable "credentials" {
  type = object({
    clientId = string    
    clientSecret = string
    subscriptionId = string
    tenantId = string
  })
}

variable "resourceGroup" {

    type = object({
        name = string
        location = string
    })

    default = {
        name = "ncird-delas-dev"
        location = "eastus"
    }
}

#variable "storageAccount" {
 #   type = object({
  #      name = string
   #     location = string
   # })

#}

variable "tags" {

    type = object({
        env = string
        program = string
        center = string
        tenant = string
        poc = string
    })

    default = {
        env = "dev",
        center ="",
        program = "",
        tenant="",
        poc = "wyw7"
    }
}

