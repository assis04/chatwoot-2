import { frontendURL } from 'dashboard/helper/URLHelper.js';

import GroupManagementView from './GroupManagementView.vue';

const groupManagementRoutes = {
  routes: [
    {
      path: frontendURL('accounts/:accountId/gestao-grupos'),
      name: 'group_management_index',
      meta: {
        permissions: ['administrator', 'agent', 'custom_role'],
      },
      component: GroupManagementView,
    },
  ],
};

export default groupManagementRoutes;
