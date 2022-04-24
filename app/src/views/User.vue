<template>
  <div class="container-fluid">

    <b-container>
      <b-row class="justify-content-md-center py-4">
        <b-col md="8">

        <b-card no-body class="overflow-hidden" style="max-width: 540px;">
          <b-row align-v="center">
            <b-col>
              <b-card-body>
                <b-card-title>
                  <b-avatar variant="primary" class="justify-content-md-center" size="4rem">
                    {{ user.abbreviation[0] }}
                  </b-avatar>
                </b-card-title>

                <b-list-group flush>
                  <b-list-group-item>Username: <b-badge variant="info">  {{ user.user_name[0] }} </b-badge> </b-list-group-item>
                  <b-list-group-item>Role: <b-badge variant="info">  {{ user.user_role[0] }} </b-badge> </b-list-group-item>
                  <b-list-group-item>Account created: {{ user.user_created[0] }}</b-list-group-item>
                  <b-list-group-item>E-Mail: {{ user.email[0] }}</b-list-group-item>
                  <b-list-group-item> 
                    ORCID:
                    <b-link v-bind:href="'https://orcid.org/' + user.orcid[0]" target="_blank"> 
                      {{ user.orcid[0] }}
                    </b-link>
                    </b-list-group-item>
                  <b-list-group-item>
                    Token expires: 
                    <b-badge class="ml-1" variant="info">{{ Math.floor(this.time_to_logout) }} m {{ ((this.time_to_logout - Math.floor(this.time_to_logout)) * 60).toFixed(0) }} s</b-badge>
                    <b-badge class="ml-1" @click="refreshWithJWT" href="#" variant="success" pill><b-icon icon="arrow-repeat" font-scale="1.0"></b-icon></b-badge>
                  </b-list-group-item>

                  <b-list-group-item>
                    <b-button 
                      class="m-1"
                      size="sm"
                      :class="pass_change_visible ? null : 'collapsed'"
                      :aria-expanded="pass_change_visible ? 'true' : 'false'"
                      aria-controls="collapse-4"
                      @click="pass_change_visible = !pass_change_visible"
                    >
                      Change password
                    </b-button>
                    <b-collapse id="collapse-pass-change" v-model="pass_change_visible">
                      <validation-observer ref="observer" v-slot="{ handleSubmit }">
                        <b-form @submit.stop.prevent="handleSubmit(changePassword)">

                          <validation-provider 
                            name="password" 
                            :rules="{ required: true, min: 5, max: 50 }" 
                            v-slot="validationContext"
                          >
                          <b-form-group
                          description="Enter your current password"
                          >
                            <b-form-input
                              v-model="current_password"
                              placeholder="Current password"
                              type="password"
                              :state="getValidationState(validationContext)"
                            ></b-form-input>
                          </b-form-group>
                          </validation-provider>

                          <validation-provider 
                            name="password" 
                            :rules="{ required: true, min: 7, max: 50 }" 
                            v-slot="validationContext"
                          >
                          <b-form-group
                          description="Enter your new password"
                          >
                            <b-form-input
                              v-model="new_password_entry"
                              placeholder="Enter new password"
                              type="password"
                              :state="getValidationState(validationContext)"
                            ></b-form-input>
                          </b-form-group>
                          </validation-provider>

                          <validation-provider 
                            name="password" 
                            :rules="{ required: true, min: 7, max: 50 }" 
                            v-slot="validationContext"
                          >
                          <b-form-group
                          description="Repeat your new password"
                          >
                            <b-form-input
                              v-model="new_password_repeat"
                              placeholder="Repeat new password"
                              type="password"
                              :state="getValidationState(validationContext)"
                            ></b-form-input>
                          </b-form-group>
                          </validation-provider>

                          <b-form-group>
                            <b-button class="ml-2" type="submit" variant="dark">Submit change</b-button>
                          </b-form-group>
                        </b-form>
                      </validation-observer>
                    </b-collapse>
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
          time_to_logout: 0,
          pass_change_visible: false,
          current_password: '',
          new_password_entry: '',
          new_password_repeat: ''
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
    getValidationState({ dirty, validated, valid = null }) {
      return dirty || validated ? valid : null;
    },
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
      let apiAuthenticateURL = process.env.VUE_APP_API_URL + '/alb/auth/refresh';

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
      let apiAuthenticateURL = process.env.VUE_APP_API_URL + '/alb/auth/signin';

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
    },
    async changePassword() {
      let apiChangePasswordURL = process.env.VUE_APP_API_URL + '/alb/user/password/change?user_id_pass_change=' + this.user.user_id[0] + '&old_pass=' + this.current_password + '&new_pass_1=' + this.new_password_entry + '&new_pass_2=' + this.new_password_repeat;
      try {
        let response_password_change = await this.axios.put(apiChangePasswordURL, {}, {
          headers: {
            'Authorization': 'Bearer ' + localStorage.getItem('token')
          }
        });
        this.makeToast(response_password_change.data.message + ' (status ' + response_password_change.status + ')', 'Success', 'success');
        this.pass_change_visible = false;
        } catch (e) {
          console.error(e.response.status);
          this.makeToast(e, 'Error', 'danger');
          this.pass_change_visible = false;
        }
      this.resetPasswordForm();
    },
    resetPasswordForm() {
      this.current_password = '';
      this.new_password_entry = '';
      this.new_password_repeat = '';
    },
    makeToast(event, title = null, variant = null) {
        this.$bvToast.toast('' + event, {
          title: title,
          toaster: 'b-toaster-top-right',
          variant: variant,
          solid: true
        })
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