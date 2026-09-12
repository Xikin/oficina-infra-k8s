# ADR-0007: EKS gerenciado em vez de k3s de nó único

**Status:** Aceita — substitui a recomendação de cluster da RFC-0001
**Data:** 2026-09-09

## Contexto

A [RFC-0001](https://github.com/Xikin/tech_challenge/blob/main/docs/rfc/0001-escolha-do-provedor-de-nuvem.md)
recomendava **não usar EKS** e sim k3s provisionado num único EC2 `t3.small`, para
evitar o custo fixo de ~US$0,10/h do control plane gerenciado.

Ao detalhar a implementação, três problemas apareceram:

1. **Não atende ao requisito.** O enunciado pede "Cluster Kubernetes **com
   escalabilidade**". Num nó único, o HPA escala pods apenas até saturar 2 vCPU /
   2 GiB — o `maxReplicas: 10` declarado em `k8s/hpa.yaml` é inatingível na prática.
   Nada escala a capacidade que hospeda os pods.
2. **Ponto único de falha admitido.** A própria RFC-0001 reconhece isso nos
   trade-offs. Réplicas de pod num nó só não sobrevivem à perda do nó.
3. **Enfraquece o argumento de IaC.** k3s exige provisionamento imperativo via
   `user_data`/`remote-exec`. O estado real do cluster deixa de ser descrito pelo
   Terraform.

O custo, que era o único argumento a favor, mostrou-se administrável: o control
plane sai por ~US$2,40/dia e a stack pode ser destruída entre sessões de estudo.

## Decisão

**Amazon EKS** com **Managed Node Group** (`min 2 / max 4`, `t3.small`), mais
`metrics-server` instalado como addon gerenciado do EKS.

A escalabilidade passa a ter duas camadas complementares:

| Camada | Mecanismo | Responde a |
| --- | --- | --- |
| Pods | HPA (`autoscaling/v2`, CPU 70% / memória 80%) | carga da aplicação |
| Nós | EKS Managed Node Group autoscaling | pods `Pending` por falta de capacidade |

O `terraform destroy` vira operação rotineira, documentada e exposta como
`workflow_dispatch`, para controlar o consumo de crédito.

## Consequências

**Positivas**
- Atende ao requisito de forma verificável: dá para provar no vídeo com um teste de
  carga que dispara `kubectl get hpa` e depois `kubectl get nodes`.
- Control plane com alta disponibilidade e upgrades gerenciados pela AWS.
- O `k8s/hpa.yaml` herdado da Fase 2 é aproveitado sem alteração — o que faltava era
  substrato, não manifesto.

**Negativas**
- ~US$2,40/dia de control plane, mesmo ocioso. Exige disciplina de `destroy`.
- Provisionamento mais lento (~12–15 min contra ~3 min do k3s), o que torna o ciclo
  de tentativa e erro mais caro.
- `t3.small` continua modesto; o `max_size = 4` é o teto econômico, não técnico.

## Consequências para a RFC-0001

A RFC-0001 permanece válida na escolha da **AWS** como provedor. A seção que
recomenda k3s em EC2 fica **superada por este ADR** e deve ser lida como alternativa
considerada e descartada.
