<template>
  <div class="container-fluid" style="min-height:90vh">

    <b-container>
      <b-row class="justify-content-md-center py-4">
        <b-col md="8">

        <b-card no-body class="overflow-hidden" style="max-width: 540px;">
          <b-row align-v="center">
            <b-col>
              <b-card-body>
                <b-card-title>
                  <b-avatar variant="primary" class="justify-content-md-center" size="4rem">
                    {{ this.user.abbreviation[0] }}
                  </b-avatar>
                </b-card-title>

                <b-list-group flush>
                  <b-list-group-item>Username: <b-badge variant="info">  {{ this.user.user_name[0] }} </b-badge> </b-list-group-item>
                  <b-list-group-item>Role: <b-badge variant="info">  {{ this.user.user_role[0] }} </b-badge> </b-list-group-item>
                  <b-list-group-item>Account created: {{ this.user.user_created[0] }}</b-list-group-item>
                  <b-list-group-item>E-Mail: {{ this.user.email[0] }}</b-list-group-item>
                  <b-list-group-item> 
                    ORCID:
                    <b-link v-bind:href="'https://orcid.org/' + this.user.orcid[0]" target="_blank"> 
                      {{ this.user.orcid[0] }}
                    </b-link>
                    </b-list-group-item>
                  <b-list-group-item>
                    Token expires: 
                    <b-badge variant="info">{{this.time_to_logout}} min</b-badge>
                    <b-badge @click="refreshWithJWT" href="#" variant="success" pill><b-icon icon="arrow-repeat" font-scale="1.0"></b-icon></b-badge>
                  </b-list-group-item>
                </b-list-group>

              </b-card-body>
            </b-col>
          </b-row>
        </b-card>

          </b-col>
        </b-row>
      </b-container>

  </div>
</template>

<script>
export default {
  name: 'User',
  data() {
        return {
          user: {
            "user_id": [],
            "user_name": [],
            "email": [],
            "user_role": [],
            "user_created": [],
            "abbreviation": [],
            "orcid": [],
            "exp": []
          },
          time_to_logout: 0
        }
  },
  mounted() {
    if (localStorage.user) {
      this.user = JSON.parse(localStorage.user);

    this.interval = setInterval(() => {
      this.updateDiffs();
    },1000);
    this.updateDiffs();

    }
  },
  methods: {
    updateDiffs() {
      if (localStorage.token) {
        let expires = JSON.parse(localStorage.user).exp;
        let timestamp = Math.floor(new Date().getTime() / 1000);

        if (expires > timestamp) {
          this.time_to_logout = ((expires - timestamp) / 60).toFixed(2);
          if (expires - timestamp == 60) {
          this.makeToast('Refresh token.', 'Logout in 60 seconds', 'danger');
          }
        } else {
          this.doUserLogOut();
        }
      }
    }, 
    async refreshWithJWT() {
      let apiAuthenticateURL = process.env.VUE_APP_API_URL + '/api/auth/refresh';

      try {
        let response_refresh = await this.axios.get(apiAuthenticateURL, {
        headers: {
          'Authorization': 'Bearer ' + localStorage.getItem('token')
        }
        });
  
        localStorage.setItem('token', response_refresh.data[0]);
        this.signinWithJWT();

        } catch (e) {
        console.error(e);
        }
    }, 
    async signinWithJWT() {
      let apiAuthenticateURL = process.env.VUE_APP_API_URL + '/api/auth/signin';

      try {
        let response_signin = await this.axios.get(apiAuthenticateURL, {
        headers: {
          'Authorization': 'Bearer ' + localStorage.getItem('token')
        }
        });

        localStorage.setItem('user', JSON.stringify(response_signin.data));

        } catch (e) {
        console.error(e);
        }
    }
  }
}
</script>


<style scoped>
.btn-group-xs > .btn, .btn-xs {
  padding: .25rem .4rem;
  font-size: .875rem;
  line-height: .5;
  border-radius: .2rem;
}
</style>