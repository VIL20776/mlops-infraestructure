# Levantamiento de la infraestructura

### Rol IAM para Github Actions
1. En el IAM Dashboard, seleccione la opción Roles.
2. Presione el botón de Create Role.
3. Al abrirse la ventana de la configuración del rol, en Trusted Entity Type, seleccione la opción Custom Trust Policy.
4. En el campo inferior llamado Custom Trust Policy, se debe copiar y pegar la configuración en formato JSON de abajo.
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated":
                "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                },
                "StringLike": {
                    "token.actions.githubusercontent.com:sub":
                    "repo:<USER/REPO>:ref:refs/heads/main"
                }
            }
        }
    ]
}
```
Reemplace <ACCOUNT_ID> con el Id la cuenta de AWS, USER con en nombre de usuario/organización de github y REPO con el nombre del repositorio.

5. Presione el botón Next.
6. En el siguiente paso de configuración se deben seleccionar los permisos que tendrá este rol. En la barra de búsqueda se deben buscar y seleccionar los siguientes:

    - AmazonRDSFullAccess
    - AmazonS3FullAccess
    - AmazonEC2FullAccess

7. Una vez seleccionados todos estos permisos presione el botón siguiente.
8. En el siguiente paso de configuración de rol, en la sección de Role Details o Detalles de Rol, en el campo de Role name ingresar:

**mlops-github-actions-role**

9. Presione el botón de Create Role.
10. Aún en la sección de roles, haga click en el nuevo rol que ha creado.
11. Seleccione la opción de Add Permissions y luego seleccionar la opción de Create Inline Policy.
12. En la nueva vista que se abrirá, seleccione la opción de JSON.
13. Pegue en el editor de texto el siguiente contenido:
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "InfraestructuraCore",
            "Effect": "Allow",
            "Action": [
                "rds:*",
                "ec2:*",
                "s3:*",
                "sqs:*",
                "ecr:*",
                "lambda:*",
                "cloudwatch:*",
                "logs:*"
            ],
            "Resource": "*"
        },
        {
            "Sid": "GestionDeRolesYPoliticasIAM",
            "Effect": "Allow",
            "Action": [
                "iam:CreateRole",
                "iam:DeleteRole",
                "iam:UpdateRole",
                "iam:GetRole",
                "iam:List*",
                "iam:TagRole",
                "iam:UntagRole",
                "iam:GetRolePolicy",
                "iam:PutRolePolicy",
                "iam:DeleteRolePolicy",
                "iam:AttachRolePolicy",
                "iam:DetachRolePolicy",
                "iam:CreateInstanceProfile",
                "iam:DeleteInstanceProfile",
                "iam:GetInstanceProfile",
                "iam:AddRoleToInstanceProfile",
                "iam:RemoveRoleFromInstanceProfile",
                "iam:GetUser",
                "iam:CreatePolicy",
                "iam:DeletePolicy",
                "iam:GetPolicy",
                "iam:GetPolicyVersion",
                "iam:CreatePolicyVersion",
                "iam:DeletePolicyVersion"
            ],
            "Resource": "*"
        },
        {
            "Sid": "PassRoleSeguro",
            "Effect": "Allow",
            "Action": "iam:PassRole",
            "Resource": "*","Condition": {
                "StringEquals": {
                    "iam:PassedToService": [
                        "ec2.amazonaws.com",
                        "rds.amazonaws.com"
                    ]
                }
            }
        }
    ]
}
```
14. Presione el botón en la parte inferior de Next.
15. En el campo de nombre de política ingresar el valor:

**mlops-github-actions-policy**

16. Cree la política.

### Backend S3 de Terraform
Para que Terraform pueda actualizar y mantener un historial de los cambios realizados en la infraestructura de nube, es necesario crear un bucket S3. Esta bucket además será usada para guardar el archivo terraform.tfvars que contiene el registro de los proyectos integrados a la infraestructura, además de otras configuraciones de la infraestructura.

1. En la barra de búsqueda del portal web de AWS buscar S3 e ingrese a la opción.
2. Presione el botón de Create bucket.
3. En el Bucket Type seleccione General Purpose.
4. En el campo de Bucket Name ingrese un nombre a su elección. Este nombre será usado posteriormente.
5. En la opción Bucket Versioning seleccionar Enable.
6. Presione el botón de Create Bucket.

### Variables de Terraform
Puede usar un archivo terraform.tfvars para definir las siguietes variables:

+ **vpc_cidr:** Bloque CIDR a usar para la VPC. El valor por defecto es "10.10.0.0/16"
+ **allowed_cidr_source:** Bloque CIRD usado para determinar las direcciones IP que pueden acceder a los servidores de MLOps y de despliegue. El valor por defecto es "0.0.0.0/0"
+ **mlflow_db_user:** Nombre del usuario de la base de datos de MLFlow. El valor por defecto es "mlflow".
+ **mlflow_db_passwd:** Nombre del usuario de la base de datos de MLFlow. El valor por defecto es "password".

Para guardar el archivo terraform.tfvars. Ejecute el commando `./scripts/backup_config.sh` desde el direcotrio raíz del repositorio o suba de forma manual el archivo `terraform.tfvars` a la Bucket S3 definida para el backend de terraform.
Finalmente, ejecute el workflow **Deploy and Update Infraestructure** para hacer efectivos sus cambios.

### Secretos de Github
Para poder ejecutar los workflows se necesita definir los siguientes secretos en el repositorio de Github.

+ **AWS_ACCOUNT_ID:** ID de la cuenta de AWS.
+ **AWS_REGION**: Region de AWS donde se desplegarán los recursos.
+ **S3_TERRAFORM_BACKEND_BUCKET**: Nombre del Bucket S3 creado previamente.

### Workflows
En la pestaña de Actions verá los workflows definidos para manejar la infraestructura.

+ **Deploy Bare Infraestrucutre:** Este workflow genera la infraestructura inicial en AWS sin usuarios/proyectos integrados y sin el servidor de despliegue. Ejecute este workflow para levantar por primera vez la infraestructura. Despliegue el output del paso "Apply Terraform" para obtener la URL del servidor de MLFLow y el nombre de a función lambda.

+ **Build and Deploy Server Image:** Este workflow crea la imagen Docker del servidor de despliegue definido en la carpeta server. Ejecute este workflow después de levantar la infraestructura por primera vez y cuando actualice el código del servidor. Despliegue el output del paso "Apply Terraform" para obtener la URL de los servidores MLFloy y de despliegue, los roles de usuarios, ids de los proyectos y la función lambda de entrenamiento.

+ **Deploy and Update Infrestructure:** Este workflow actualiza la infraestructura e integra a los usuarios de la misma. Ejecute este workflow siempre que quiera realizar cambios a los archivo de terraform y al actualiza el archivo terraform.tfvars. <br>
Vea el documento de [integración de usuarios](INTEGRATION.md) para más detalles.

+ **Destroy Infraestrucutre:** Este workflow destruye las infraestructura levantada en AWS. 

