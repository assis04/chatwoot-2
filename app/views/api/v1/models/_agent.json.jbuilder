json.id resource.id
# could be nil for a deleted agent hence the safe operator before account id
json.account_id Current.account&.id
json.availability_status resource.availability_status
json.auto_offline resource.auto_offline
json.confirmed resource.confirmed?
json.email resource.email
json.provider resource.provider
json.available_name resource.available_name
json.custom_attributes resource.custom_attributes if resource.custom_attributes.present?
json.name resource.name
json.role resource.role
json.thumbnail resource.avatar_url
# Fork Valcenter (CE): custom_roles foi reconstruido na base, entao expomos o
# custom_role_id sempre — nao so no EE. Sem isso o front nunca recebe a funcao e a
# tela de Agentes mostra so "Agente"/"Administrador". Ver [[chatwoot-community-edition-migration]].
json.custom_role_id resource.current_account_user&.custom_role_id
