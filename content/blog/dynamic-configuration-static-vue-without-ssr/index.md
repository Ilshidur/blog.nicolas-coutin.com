---
title: Dynamic configuration for static Vue 2 apps without SSR
date: "2019-06-27T23:59:00.000"
description: "How to configure a statically generated Vue 2 application at run time, without `VUE_APP_` environment variables."
---

This article explains how to allow our Vue.js (version 2.x) app to accept configurations at **run time** instead of **build time** using [Docker](https://www.docker.com) & [NGINX](https://www.nginx.com).

**If you want the solution, you can skip to the *Solution* section.**

## Why ?

At [Scalair](https://www.scalair.fr), we use Docker to deploy our applications. Some of our applications are Vue.js **static** front ends, served through NGINX. We use *Gitlab CI* to test & deploy our code to *Amazon EKS*. Each Gitlab pipeline builds our app, then pushes the Docker image to Amazon ECR.

Our Vue apps had configurations like this, [thanks to Vue.js client-side env vars](https://cli.vuejs.org/guide/mode-and-env.html#using-env-variables-in-client-side-code) :

```javascript
const API_URL = process.env.VUE_APP_API_URL;
```

Due to the lack of [Server-Side Rendering](https://vuejs.org/v2/guide/ssr.html) in our Vue app, we used to give environment variables to the Vue CLI at build time in order to provide configurations, e.g.: an API URL.

We also had a Dockerfile that we used to build using `docker build --build-arg API_URL=https://api.example.com .` :

```dockerfile
# Build stage
FROM mhart/alpine-node:10 as build-stage

WORKDIR /app

COPY package.json package-lock.json .npmrc ./
RUN npm ci

COPY . .

ARG API_URL
ENV VUE_APP_API_URL $API_URL

RUN ./node_modules/.bin/vue-cli-service build --mode production

# Production stage
FROM nginx:1.17.0-alpine as production-stage
COPY --from=build-stage /app/dist /usr/share/nginx/html
EXPOSE 80

CMD nginx -g "daemon off;"
```

This multi-stage build will build the static files, then serve them with NGINX.

**One concern we had was the consistency of our images : a Docker image would differ from one environment to an other because of the `--build-arg` parameter. The `VUE_APP_` env vars only work at **build time**.**

## Solution

Let the NGINX container do the job !

We replaced `process.env.VUE_APP_API_URL` with `'{{ API_URL }}'` :

```javascript
// This will act as a "template" that will be replaced with an actual URL.
const API_URL = '{{ API_URL }}';
```

Then we removed the build args & replaced the `{{ templates }}` before running NGINX.

**Final Dockerfile :**

```dockerfile
# Build stage
FROM mhart/alpine-node:10 as build-stage

WORKDIR /app

COPY package.json package-lock.json .npmrc ./
RUN npm ci

COPY . .

RUN ./node_modules/.bin/vue-cli-service build --mode production

# Production stage
FROM nginx:1.17.0-alpine as production-stage
COPY --from=build-stage /app/dist /usr/share/nginx/html
EXPOSE 80

# Using `sed` to replace {{ API_URL }} with the actual API URL,
# which is given to the container at RUN TIME !
CMD sed -i -e "s/{{ API_URL }}/$API_URL/g" /usr/share/nginx/html/js/app.*.js && \
    nginx -g "daemon off;"
```

Finally, we run the container using these commands :

```bash
docker build -t my-vue-app .
docker run -e API_URL=https://api.example.com my-vue-app
```

## Conclusion

This is more a temporary solution than an actual long-term solution.

If you are facing the same issue we had, you should definitely look into [Server-Side Rendering](https://vuejs.org/v2/guide/ssr.html). SSR allows a lot of behaviors that you can't do with a single static app rendered in the browser. This is a good way to dynamically change parts of your frontend and prevent crappy hacks like we did.

## Was this article helpful ?

Feel free to drop a 👍 !

This article has been entirely written by a human.
