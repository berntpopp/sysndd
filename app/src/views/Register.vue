<template>
  <div class="container-fluid" style="min-height:90vh">
  <b-spinner label="Loading..." v-if="loading" class="float-center m-5"></b-spinner>

    <b-container v-else>
      <b-row class="justify-content-md-center py-4">
        <b-col md="6">
          <b-card
          header="Register new account"
          header-bg-variant="dark"
          header-text-variant="white"
          >
          <b-card-text>

            <b-form @submit="onSubmit">
              <b-form-group
                description="Enter your prefered user name"
              >
                <b-form-input
                  v-model="registration_form.user_name"
                  placeholder="User"
                  required
                ></b-form-input>
              </b-form-group>

              <b-form-group
                description="Enter your institutional mail account"
              >
                <b-form-input
                  v-model="registration_form.email"
                  placeholder="mail@your-institution.com"
                  required
                ></b-form-input>
              </b-form-group>

              <b-form-group
                description="Enter your ORCID"
              >
                <b-form-input
                  v-model="registration_form.orcid"
                  placeholder="XXXX-XXXX-XXXX-XXXX"
                  required
                ></b-form-input>
              </b-form-group>

              <b-form-group
                description="Enter your first name"
              >
                <b-form-input
                  v-model="registration_form.first_name"
                  placeholder="First name"
                  required
                ></b-form-input>
              </b-form-group>

              <b-form-group
                description="Enter your family name"
              >
                <b-form-input
                  v-model="registration_form.family_name"
                  placeholder="Family name"
                  required
                ></b-form-input>
              </b-form-group>

              <b-form-group
                description="Please describe why you want to help with SysNDD"
              >
                <b-form-input
                  v-model="registration_form.comment"
                  placeholder="Your interest in SysNDD"
                  required
                ></b-form-input>
              </b-form-group>

              <b-form-group>
                <b-button type="submit" variant="outline-dark">Register</b-button>
              </b-form-group>
              </b-form>
            
            </b-card-text>  
            </b-card>
          </b-col>
        </b-row>
      </b-container>

  </div>
</template>

<script>
export default {
  name: 'Register',
  data() {
      return {
        registration_form: {
          user_name: '',
          email: '',
          orcid: '',
          first_name: '',
          family_name: '',
          comment: '',
        },
        loading: true
      }
    },
  mounted() {
    if (localStorage.user) {
      this.doUserLogOut();
    }
    this.loading = false;
  },
  methods: {
    async sendRegistration() {

    console.log(JSON.stringify(this.registration_form));

    let apiUrl = process.env.VUE_APP_API_URL + '/api/auth/signup?signup_data=' ;

      try {
        let submission_json = JSON.stringify(this.registration_form);
        console.log(submission_json);
        let response = await this.axios.get(apiUrl + submission_json, {} );
        console.log(response);
      } catch (e) {
        console.error(e);
      }

    }, 
    onSubmit(event) {
      event.preventDefault();
      this.sendRegistration();
    },
    doUserLogOut() {
      if (localStorage.user || localStorage.token) {
        localStorage.removeItem('user');
        localStorage.removeItem('token');
        this.user = null;
        this.$router.push('/');
      }
    }
  }
}
</script>

<!-- Add "scoped" attribute to limit CSS to this component only -->
<style scoped>
h3 {
  margin: 40px 0 0;
}
ul {
  list-style-type: none;
  padding: 0;
}
li {
  display: inline-block;
  margin: 0 10px;
}
a {
  color: #42b983;
}
</style>