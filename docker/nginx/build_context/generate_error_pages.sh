#!/usr/bin/env bash

while IFS= read -r title; do
  read -r code msg <<< "$title"

  case $code in
    301|302|303|307|308)
      continue
      ;;
  esac

  cat <<-EOF
	error_page ${code} @${code}_location;
	
	location /${code}.json {
	    internal;
	    return ${code} '{"error":{"code":${code},"message":"${msg}"},"message":"${title}"}\n';
	}

	location /${code}.html {
	    internal;
	    return ${code} '<!DOCTYPE html><html lang="en"><head><title>${title}</title></head><body><center><h1>${title}</h1></center></body></html>\n';
	}

	location @${code}_location {
	    internal;
	    rewrite ^ /${code}.\$accept_ext;
	}

	EOF
done < <(sed -E -n 's!"<head><title>([[:digit:]]{3}) ([^,]+)</title></head>" CRLF$!\1 \2!p' src/http/ngx_http_special_response.c)

