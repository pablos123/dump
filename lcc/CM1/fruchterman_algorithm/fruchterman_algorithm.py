"""Bad implementation of the Fruchterman Algorithm"""

# sudo apt install python3-matplotlib

import matplotlib.pyplot as plt
import argparse
import time as t

import math as m
import random as rand
import numpy as np


class Graph:
    def __init__(
        self,
        name,
        iterations,
        repulsion_c=1,
        atraction_c=1,
        temperature=3,
        gravity=1,
        width=1000,
        height=1000,
        refresh=1,
        verbose=False,
    ):
        self.width = width
        self.height = height
        self.iterations = iterations
        self.refresh = refresh
        self.repulsion_c = repulsion_c
        self.atraction_c = atraction_c
        self.verbose = verbose
        self.t = temperature
        self.gravity = gravity

        with open("./graphs/" + name, "r") as f:
            line = f.readline()
            nodes_count = int(line)
            i = 0
            nodes = {}
            while i < nodes_count:
                line = f.readline().rstrip()
                nodes[line] = self.asign_coordinates()
                i = i + 1
            edges = []
            for line in f:
                splited_line = line.split(" ")
                edge = (splited_line[0], splited_line[1].rstrip())
                edges.append(edge)

        self.edges = edges
        self.nodes = nodes

        area = self.width * self.height
        self.k = m.sqrt(area / len(self.nodes.keys()))

    def asign_coordinates(self):
        return {
            "x": rand.randint(-int(self.width / 2), int(self.width / 2)),
            "y": rand.randint(-int(self.height / 2), int(self.height / 2)),
            "acum_x": 0,
            "acum_y": 0,
        }

    def get_coordinates(self):
        xpoints = []
        ypoints = []

        for v, u in self.edges:
            xpoints.append(self.nodes[v]["x"])
            ypoints.append(self.nodes[v]["y"])
            xpoints.append(self.nodes[u]["x"])
            ypoints.append(self.nodes[u]["y"])

        return (xpoints, ypoints)

    def compute_attraction_forces(self):
        for e in self.edges:
            v = np.array((self.nodes[e[0]]["x"], self.nodes[e[0]]["y"]))
            u = np.array((self.nodes[e[1]]["x"], self.nodes[e[1]]["y"]))
            delta_x = v[0] - u[0]
            delta_y = v[1] - u[1]
            distance = np.linalg.norm(v - u)

            if distance != 0:
                fa = (distance**2) / (self.k * self.atraction_c)
                self.nodes[e[0]]["acum_x"] -= (delta_x / distance) * fa
                self.nodes[e[0]]["acum_y"] -= (delta_y / distance) * fa

                self.nodes[e[1]]["acum_x"] += (delta_x / distance) * fa
                self.nodes[e[1]]["acum_y"] += (delta_y / distance) * fa
            else:
                self.apply_repulsion(v, u)

    def compute_repulsion_forces(self):
        for v in self.nodes.values():
            v["acum_x"] = 0
            v["acum_y"] = 0
            for u in self.nodes.values():
                if v != u:
                    v_a = np.array((v["x"], v["y"]))
                    u_a = np.array((u["x"], u["y"]))

                    delta_x = v_a[0] - u_a[0]
                    delta_y = v_a[1] - u_a[1]
                    distance = np.linalg.norm(v_a - u_a)
                    if distance != 0:
                        fr = ((self.k * self.repulsion_c) ** 2) / distance

                        v["acum_x"] += (delta_x / distance) * fr
                        v["acum_y"] += (delta_y / distance) * fr
                    else:
                        self.apply_repulsion(v, u)
        return

    def update_positions(self):
        for n in self.nodes.values():
            acum_dist = np.linalg.norm([n["acum_x"], n["acum_y"]])
            if acum_dist > self.t:
                n["acum_x"], n["acum_y"] = (
                    (n["acum_x"] / acum_dist) * self.t,
                    (n["acum_y"] / acum_dist) * self.t,
                )

            n["x"] += n["acum_x"]
            n["y"] += n["acum_y"]

            n["x"] = min(self.width / 2, max(-self.width / 2, n["x"]))
            n["y"] = min(self.height / 2, max(-self.height / 2, n["y"]))

        self.t *= 0.99
        return

    def compute_gravity(self):
        for v in self.nodes.values():
            v["acum_x"] -= v["x"] * self.gravity
            v["acum_y"] -= v["y"] * self.gravity

    def apply_repulsion(self, v, u):
        delta_x = v[0] - u[0]
        delta_y = v[1] - u[1]

        distance = rand.randint(0.1, self.width / 2)
        fr = ((self.k * self.repulsion_c) ** 2) / distance
        v["acum_x"] += (delta_x / distance) * fr
        v["acum_y"] += (delta_y / distance) * fr


def fruchterman_algorithm():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "-f",
        "--file_name",
        help="Archivo del cual leer el grafo a dibujar",
        default="malla",
    )

    parser.add_argument(
        "-i",
        "--iters",
        type=int,
        help="Cantidad de iteraciones a efectuar",
        default=1000,
    )

    parser.add_argument(
        "-c1", "--repulsion_c", type=float, help="Constante de repulsion", default=1.0
    )

    parser.add_argument(
        "-c2", "--atraction_c", type=float, help="Constante de atraccion", default=1.0
    )

    parser.add_argument(
        "-t", "--temp", type=float, help="Temperatura inicial", default=10.0
    )

    parser.add_argument(
        "-g", "--gravity", type=float, help="Fuerza de atraccion central", default=0.5
    )

    parser.add_argument(
        "-wi", "--width", type=int, help="Ancho de la ventana", default=1000
    )

    parser.add_argument(
        "-he", "--height", type=int, help="Alto de la ventana", default=1000
    )

    parser.add_argument(
        "-r",
        "--refresh",
        type=int,
        help="Cada cuantas iteraciones dibujar el grafo 0 es el estado final",
        default=1,
    )

    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="Muestra mas informacion al correr el programa",
        default=False,
    )

    args = parser.parse_args()

    graph = Graph(
        name=args.file_name,
        iterations=args.iters,
        repulsion_c=args.repulsion_c,
        atraction_c=args.atraction_c,
        temperature=args.temp,
        gravity=args.gravity,
        width=args.width,
        height=args.height,
        refresh=args.refresh,
        verbose=args.verbose,
    )

    ###########################
    #     initialize plot     #
    ###########################

    ######################################################
    plt.ion()
    figure, ax = plt.subplots(figsize=(20, 20), dpi=50)
    ax.set_xlim(-graph.width / 2, graph.width / 2)
    ax.set_ylim(-graph.height / 2, graph.height / 2)
    ax.set_autoscale_on(False)
    plt.subplots_adjust(left=0.0, right=1.0, bottom=0.0, top=1.0)
    ######################################################

    for i in range(0, graph.iterations):
        ###########################
        #     update plot     #
        ###########################

        ######################################################

        if (graph.refresh != 0) and (i % graph.refresh == 0):
            xpoints, ypoints = graph.get_coordinates()

            for i in range(0, len(xpoints) - 1, 2):
                ax.plot(
                    [xpoints[i], xpoints[i + 1]],
                    [ypoints[i], ypoints[i + 1]],
                    marker="o",
                    ms=10,
                )

            figure.canvas.flush_events()
            ax.clear()
            ######################################################

        graph.compute_repulsion_forces()

        graph.compute_attraction_forces()

        graph.compute_gravity()

        graph.update_positions()

    if graph.refresh == 0:
        xpoints, ypoints = graph.get_coordinates()
        for i in range(0, len(xpoints) - 1, 2):
            ax.plot(
                [xpoints[i], xpoints[i + 1]],
                [ypoints[i], ypoints[i + 1]],
                marker="o",
                ms=10,
            )

        figure.canvas.flush_events()
        t.sleep(5)


if __name__ == "__main__":
    fruchterman_algorithm()
