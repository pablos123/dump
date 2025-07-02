Proof of concept of what you can archive with ansible (ugly) output, community callback plugins and other linux tools: sed and jq

If you installed Ansible with the aptitude package you have the community.general collection. collection

```
sudo apt install ansible
```

In the file `ansible.cfg` you need the line:

```
stdout_callback=oneline
```

Install `jq`:

```
sudo apt install jq
```

The command for now:

```
ansible-playbook -i inv/localhost.ini plays/nvim_setup.yml | sed -u '/censored/d' | sed -u '/stdout/d' | sed -u 's/^.* | \(.*\) => \(.*}\).*$/{"status": "\1", "data": \2}/' | jq
```

What I want to have:
- The name of the tasks y the final json.
- An idea of what to do with the json in the stdout xd
