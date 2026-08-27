import { INSTALLATION_TYPES } from 'dashboard/constants/installationTypes';
import { frontendURL } from 'dashboard/helper/URLHelper';

import SettingsWrapper from '../SettingsWrapper.vue';
import CustomRolesHome from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/custom-roles'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          redirect: 'list',
        },
        {
          path: 'list',
          name: 'custom_roles_list',
          meta: {
            // Fork Valcenter: custom_roles é feature nossa (Community, base) — NÃO
            // gateamos pelo feature flag premium (senão a tela some se o flag cair
            // num save do Super Admin). Só admin, em qualquer tipo de instalação.
            installationTypes: [
              INSTALLATION_TYPES.CLOUD,
              INSTALLATION_TYPES.ENTERPRISE,
              INSTALLATION_TYPES.COMMUNITY,
            ],
            permissions: ['administrator'],
          },
          component: CustomRolesHome,
        },
      ],
    },
  ],
};
